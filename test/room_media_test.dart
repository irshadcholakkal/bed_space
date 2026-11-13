import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bed_space/data/models/room_media_model.dart';
import 'package:bed_space/data/models/bed_model.dart';
import 'package:bed_space/data/models/room_model.dart';
import 'package:bed_space/data/services/google_drive_service.dart';
import 'package:bed_space/data/services/google_sheets_service.dart';
import 'package:bed_space/data/services/local_database_service.dart';
import 'package:bed_space/data/services/status_message_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const photo = RoomMediaModel(
    fileId: 'photo-id',
    name: 'Room photo.jpg',
    mimeType: 'image/jpeg',
    size: 100);
const video = RoomMediaModel(
    fileId: 'video-id',
    name: 'Room tour.mp4',
    mimeType: 'video/mp4',
    size: 200,
    resourceKey: 'resource');
RoomModel roomWithMedia() => RoomModel.fromJson({
      'room_id': 'room',
      'building_id': 'building',
      'room_number': '101',
      'media_json': [photo.toJson(), video.toJson()],
      'lower_bed_rent': 650,
      'upper_bed_rent': 600
    });

void main() {
  test('retrying room creation keeps saved media and existing bed occupancy',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final directory =
        await Directory.systemTemp.createTemp('bedspace_media_retry_');
    await databaseFactory.setDatabasesPath(directory.path);
    await LocalDatabaseService.selectWorkspace('room_media_retry');
    final local = LocalDatabaseService();
    final db = await local.database;
    var mutation = 0;
    Future<void> commit(String type, Map<String, dynamic> payload) =>
        local.commitMutation({
          'id': 'mutation_${mutation++}',
          'type': type,
          'payload': jsonEncode(payload),
          'timestamp': DateTime.now().toIso8601String(),
          'retry_count': 0,
        });
    try {
      await commit('ADD_ROOM', roomWithMedia().toJson());
      final bed = BedModel(
          bedId: 'stable-bed',
          roomId: 'room',
          bedType: BedType.lower,
          status: BedStatus.vacant);
      await commit('ADD_BED', bed.toJson());
      await commit('UPDATE_BED_STATUS',
          {'bedId': 'stable-bed', 'status': 'BedStatus.occupied'});
      await commit('ADD_BED', bed.toJson());
      expect((await local.getBeds()).single.status, BedStatus.occupied);
      expect((await local.getRooms()).single.media, hasLength(2));
      expect(await local.getMutationQueue(), hasLength(3));
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
  test(
      'room media survives serialization and WhatsApp includes details and Drive links',
      () {
    final room = RoomModel.fromJson(roomWithMedia().toJson());
    expect(room.media.map((media) => media.toJson()),
        [photo.toJson(), video.toJson()]);
    expect(RoomModel.fromJson({'room_id': 'legacy'}).media, isEmpty);
    final message = StatusMessageService.roomDetails(
            room: room,
            rooms: [room],
            building: 'Marina',
            address: 'Dubai',
            lowerAvailable: 1,
            upperAvailable: 2) +
        StatusMessageService.roomMediaLinks(room.media);
    expect(message, contains('Room 101'));
    expect(message, contains('Available beds: 3'));
    expect(message, contains('AED 650.00'));
    expect(message, contains(photo.viewUrl));
    expect(message, contains('Video - Room tour.mp4'));
    expect(Uri.parse(video.viewUrl).queryParameters['resourcekey'], 'resource');
    expect(StatusMessageService.whatsappUri(message).queryParameters['text'],
        message);
  });

  test('large video uploads in bounded chunks without granting permissions',
      () async {
    const size = 4 * 1024 * 1024 + 7;
    final chunkSizes = <int>[];
    final progress = <double>[];
    final client = MockClient((request) async {
      expect(request.url.path, isNot(contains('permissions')));
      if (request.method == 'GET') return http.Response('{"files":[]}', 200);
      if (request.method == 'POST') {
        expect(request.url.queryParameters['uploadType'], 'resumable');
        expect(jsonDecode(request.body)['parents'], ['folder']);
        expect(request.headers['X-Upload-Content-Length'], '$size');
        return http.Response('', 200,
            headers: {'location': 'https://www.googleapis.com/upload/session'});
      }
      chunkSizes.add(request.bodyBytes.length);
      expect(request.headers['Authorization'], 'Bearer token');
      if (chunkSizes.length == 1) {
        expect(request.headers['Content-Range'], 'bytes 0-4194303/$size');
        return http.Response('', 308, headers: {'range': 'bytes=0-4194303'});
      }
      expect(request.headers['Content-Range'], 'bytes 4194304-4194310/$size');
      return http.Response(
          jsonEncode({
            'id': 'saved',
            'name': 'tour.mp4',
            'mimeType': 'video/mp4',
            'size': '$size'
          }),
          200);
    });
    final result = await GoogleDriveService(client).uploadRoomMedia(
        token: 'token',
        folderId: 'folder',
        filename: 'tour.mp4',
        mimeType: 'video/mp4',
        size: size,
        uploadKey: 'upload',
        bytes: Stream.value(Uint8List(size)),
        onProgress: progress.add);
    expect(result.fileId, 'saved');
    expect(chunkSizes, [4 * 1024 * 1024, 7]);
    expect(progress.last, 1);
    client.close();
  });

  test(
      'a completed upload is recovered after a lost response without another upload',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
          request.url.queryParameters['q'], contains("value='stable-upload'"));
      return http.Response(
          jsonEncode({
            'files': [
              {
                'id': 'saved',
                'name': 'photo.jpg',
                'mimeType': 'image/jpeg',
                'size': '100'
              }
            ]
          }),
          200);
    });
    final result = await GoogleDriveService(client).uploadRoomMedia(
        token: 'token',
        folderId: 'folder',
        filename: 'photo.jpg',
        mimeType: 'image/jpeg',
        size: 100,
        uploadKey: 'stable-upload',
        bytes: Stream.error(StateError('The old source stream was consumed')));
    expect(result.fileId, 'saved');
    client.close();
  });

  test(
      'only selected files gain link viewing and repeated sharing reuses the permission',
      () async {
    var shared = false;
    var changes = 0;
    final client = MockClient((request) async {
      expect(request.url.path, '/drive/v3/files/photo-id/permissions');
      if (request.method == 'GET') {
        return http.Response(
            jsonEncode({
              'permissions': [
                {'type': 'user', 'role': 'owner'},
                if (shared) {'type': 'anyone', 'role': 'reader'},
              ]
            }),
            200);
      }
      expect(jsonDecode(request.body),
          {'type': 'anyone', 'role': 'reader', 'allowFileDiscovery': false});
      shared = true;
      changes++;
      return http.Response('{"id":"anyoneWithLink"}', 200);
    });
    final drive = GoogleDriveService(client);
    await drive.enableMediaLinkViewing(token: 'token', fileId: photo.fileId);
    await drive.enableMediaLinkViewing(token: 'token', fileId: photo.fileId);
    expect(changes, 1);
    client.close();
  });

  test(
      'Sheets adds column M, preserves room media and clears it on room deletion',
      () async {
    final writes = <http.Request>[];
    var expansions = 0;
    final client = MockClient((request) async {
      if (request.url.queryParameters['fields'] == 'sheets.properties') {
        return http.Response(
            jsonEncode({
              'sheets': [
                {
                  'properties': {
                    'title': 'Rooms',
                    'sheetId': 1,
                    'gridProperties': {'columnCount': 12}
                  }
                }
              ]
            }),
            200);
      }
      if (request.method == 'POST') {
        expect(
            jsonDecode(request.body)['requests'][0]['updateSheetProperties']
                ['properties']['gridProperties']['columnCount'],
            13);
        expansions++;
        return http.Response('{}', 200);
      }
      if (request.method == 'GET') {
        final row = [
          'room',
          'building',
          '101',
          '2',
          '1',
          '1',
          '650',
          '600',
          '0',
          '0',
          '',
          'TRUE',
          roomWithMedia().toJson()['media_json']
        ];
        return http.Response(
            jsonEncode({
              'values': request.url.path.endsWith('A:M') ? [[], row] : [row]
            }),
            200);
      }
      writes.add(request);
      return http.Response('{}', 200);
    });
    await http.runWithClient(() async {
      final sheets =
          GoogleSheetsService(accessToken: 'token', sheetId: 'sheet');
      expect((await sheets.getRooms()).single.media, hasLength(2));
      await sheets.addRoom(roomWithMedia());
      await sheets.deleteRoom('room');
    }, () => client);
    expect(expansions, 1);
    final rows = writes
        .map((request) =>
            (jsonDecode(request.body)['values'] as List).single as List)
        .where((row) => row.length == 13)
        .toList();
    expect(RoomMediaModel.decode(rows.first[12]), hasLength(2));
    expect(rows.last, everyElement(''));
  });

  test('version 9 rooms migrate without losing data and media persists locally',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final directory = await Directory.systemTemp.createTemp('bedspace_media_');
    await databaseFactory.setDatabasesPath(directory.path);
    final path = '${directory.path}/bed_space_legacy_room_media_upgrade.db';
    final legacy =
        await openDatabase(path, version: 9, onCreate: (db, version) async {
      await db.execute(
          'CREATE TABLE rooms(room_id TEXT PRIMARY KEY, room_number TEXT)');
      await db.insert('rooms', {'room_id': 'old', 'room_number': 'Old room'});
    });
    await legacy.close();
    await LocalDatabaseService.selectWorkspace('room_media_upgrade');
    final local = LocalDatabaseService();
    final db = await local.database;
    try {
      expect((await local.getRooms()).single.roomNumber, 'Old room');
      expect((await local.getRooms()).single.media, isEmpty);
      expect(await db.getVersion(), 10);
      final media = jsonEncode([photo.toJson(), video.toJson()]);
      await db.update('rooms', {'media_json': media},
          where: 'room_id = ?', whereArgs: ['old']);
      expect((await local.getRooms()).single.media, hasLength(2));
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
