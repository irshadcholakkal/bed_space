import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/room_media_model.dart';

class GoogleDriveService {
  final http.Client client;
  GoogleDriveService(this.client);

  StateError _error(int status) => StateError(status == 401
      ? 'Google session expired. Reconnect Google and retry.'
      : 'Drive could not complete this request. Check your connection and folder access, then retry.');

  /// Reuses a completed upload when its final response was lost.
  Future<RoomMediaModel> uploadRoomMedia(
      {required String token,
      required String folderId,
      required String filename,
      required String mimeType,
      required int size,
      required String uploadKey,
      required Stream<List<int>> bytes,
      void Function(double progress)? onProgress}) async {
    if (size <= 0 || !RoomMediaModel.mimeTypes.values.contains(mimeType)) {
      throw ArgumentError('Choose a non-empty photo or video.');
    }
    final headers = {'Authorization': 'Bearer $token'};
    String escape(String value) =>
        value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    final existing = await client
        .get(
            Uri.https('www.googleapis.com', '/drive/v3/files', {
              'q':
                  "'${escape(folderId)}' in parents and trashed = false and appProperties has { key='room_media_upload' and value='${escape(uploadKey)}' }",
              'fields': 'files(id,name,mimeType,size,resourceKey)',
              'pageSize': '1',
            }),
            headers: headers)
        .timeout(const Duration(seconds: 30));
    if (existing.statusCode != 200) throw _error(existing.statusCode);
    final matches = jsonDecode(existing.body)['files'] as List? ?? [];
    if (matches.isNotEmpty) {
      onProgress?.call(1);
      return _mediaFromDrive(matches.first);
    }
    final started = await client
        .post(
            Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
              'uploadType': 'resumable',
              'fields': 'id,name,mimeType,size,resourceKey',
            }),
            headers: {
              ...headers,
              'Content-Type': 'application/json; charset=UTF-8',
              'X-Upload-Content-Type': mimeType,
              'X-Upload-Content-Length': '$size'
            },
            body: jsonEncode({
              'name': filename,
              'parents': [folderId],
              'mimeType': mimeType,
              'appProperties': {'room_media_upload': uploadKey}
            }))
        .timeout(const Duration(seconds: 30));
    if (started.statusCode != 200) throw _error(started.statusCode);
    final session = Uri.tryParse(started.headers['location'] ?? '');
    if (session == null ||
        session.scheme != 'https' ||
        !(session.host == 'googleapis.com' ||
            session.host.endsWith('.googleapis.com'))) {
      throw StateError('Drive did not provide a valid upload session.');
    }
    var sent = 0;
    await for (final chunk in _chunks(bytes)) {
      final end = sent + chunk.length;
      if (end > size) {
        throw StateError('The selected file changed. Select it again.');
      }
      final response = await client
          .put(session,
              headers: {
                ...headers,
                'Content-Type': mimeType,
                'Content-Range': 'bytes $sent-${end - 1}/$size'
              },
              body: chunk)
          .timeout(const Duration(minutes: 2));
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (end != size) {
          throw StateError(
              'Drive received an incomplete file. Select it again to retry.');
        }
        onProgress?.call(1);
        return _mediaFromDrive(jsonDecode(response.body));
      }
      if (response.statusCode != 308) throw _error(response.statusCode);
      if (response.headers['range'] != 'bytes=0-${end - 1}') {
        throw StateError(
            'The upload was interrupted. Select the file again to retry.');
      }
      sent = end;
      onProgress?.call(sent / size);
    }
    throw StateError(
        'The file could not be fully uploaded. Select it again to retry.');
  }

  RoomMediaModel _mediaFromDrive(dynamic file) => RoomMediaModel(
      fileId: file['id'] as String,
      name: file['name'] as String,
      mimeType: file['mimeType'] as String,
      size: int.tryParse('${file['size']}') ?? 0,
      resourceKey: file['resourceKey'] as String?);

  Stream<Uint8List> _chunks(Stream<List<int>> source) async* {
    const size = 4 * 1024 * 1024;
    var buffer = Uint8List(size);
    var used = 0;
    await for (final segment in source) {
      var offset = 0;
      while (offset < segment.length) {
        final count = math.min(size - used, segment.length - offset);
        buffer.setRange(used, used + count, segment, offset);
        offset += count;
        used += count;
        if (used == size) {
          yield buffer;
          buffer = Uint8List(size);
          used = 0;
        }
      }
    }
    if (used > 0) yield Uint8List.sublistView(buffer, 0, used);
  }

  Future<void> enableMediaLinkViewing(
      {required String token, required String fileId}) async {
    final uri =
        Uri.https('www.googleapis.com', '/drive/v3/files/$fileId/permissions');
    final headers = {'Authorization': 'Bearer $token'};
    final current = await client
        .get(
            uri.replace(
                queryParameters: {'fields': 'permissions(id,type,role)'}),
            headers: headers)
        .timeout(const Duration(seconds: 30));
    if (current.statusCode != 200) throw _error(current.statusCode);
    final permissions = jsonDecode(current.body)['permissions'] as List? ?? [];
    if (permissions.any((permission) =>
        permission['type'] == 'anyone' &&
        ['reader', 'writer'].contains(permission['role']))) {
      return;
    }
    final response = await client
        .post(uri,
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'type': 'anyone',
              'role': 'reader',
              'allowFileDiscovery': false
            }))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _error(response.statusCode);
    }
  }

  /// Upload a private PDF into the connected customer's folder.
  /// No permissions are created; the folder's existing sharing applies.
  Future<String> uploadPdf(
      {required String token,
      required String folderId,
      required String filename,
      required Uint8List bytes}) async {
    final boundary = 'bedspace_${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': filename,
      'parents': [folderId],
      'mimeType': 'application/pdf'
    });
    final body = BytesBuilder()
      ..add(utf8.encode(
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n--$boundary\r\nContent-Type: application/pdf\r\n\r\n'))
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));
    final response = await client
        .post(
            Uri.https('www.googleapis.com', '/upload/drive/v3/files',
                {'uploadType': 'multipart', 'fields': 'id'}),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'multipart/related; boundary=$boundary'
            },
            body: body.takeBytes())
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError(response.statusCode == 401
          ? 'Google session expired. Reconnect Google and try again.'
          : 'Drive could not save the document. Check folder access and try again.');
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
  }
}
