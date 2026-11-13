import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/room_media_model.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/management_repository.dart';
import '../../data/repositories/sheet_repository.dart';
import '../../data/services/google_drive_service.dart';
import '../../data/services/google_sheets_service.dart';
import 'package:provider/provider.dart';

class _MediaSelection {
  PlatformFile file;
  final String uploadKey = const Uuid().v4();
  RoomMediaModel? uploaded;
  bool attempted = false;
  _MediaSelection(this.file);
}

class RoomMediaPicker extends StatefulWidget {
  final List<RoomMediaModel> initialMedia;
  final bool enabled;
  const RoomMediaPicker(
      {super.key, this.initialMedia = const [], this.enabled = true});
  @override
  State<RoomMediaPicker> createState() => RoomMediaPickerState();
}

class RoomMediaPickerState extends State<RoomMediaPicker> {
  late final _saved = List<RoomMediaModel>.of(widget.initialMedia);
  final _files = <_MediaSelection>[];
  bool _busy = false;
  String? _error;
  String? _uploading;
  double _progress = 0;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: RoomMediaModel.mimeTypes.keys.toList(),
          allowMultiple: true,
          withData: false,
          withReadStream: true);
      if (!mounted || result == null) return;
      setState(() {
        for (final file in result.files) {
          final previous = _files
              .where((item) =>
                  item.file.name == file.name && item.file.size == file.size)
              .firstOrNull;
          if (previous == null) {
            _files.add(_MediaSelection(file));
          } else if (previous.uploaded == null) {
            previous.file = file;
            previous.attempted = false;
          }
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<RoomMediaModel>> uploadSelected() async {
    if (_busy) throw StateError('Wait for file selection to finish.');
    if (_files.every((item) => item.uploaded != null)) {
      return [..._saved, ..._files.map((item) => item.uploaded!)];
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = http.Client();
    try {
      final repository = SheetRepository();
      final token = await repository.getToken();
      final sheetId = await repository.getSheetId();
      if (token == null || sheetId == null) {
        throw StateError('Connect Google before uploading room media.');
      }
      final folder = await repository.getDriveFolderId() ??
          await GoogleSheetsService.ensureDocumentFolder(
              token, 'room_media_$sheetId');
      for (final item in _files.where((item) => item.uploaded == null)) {
        final file = item.file;
        final mime = RoomMediaModel.mimeTypes[file.extension?.toLowerCase()];
        if (mime == null || file.size <= 0) {
          throw StateError('Choose a non-empty photo or video.');
        }
        if (mounted) {
          setState(() {
            _uploading = file.name;
            _progress = 0;
          });
        }
        final bytes = item.attempted
            ? Stream<List<int>>.error(
                StateError('Select ${file.name} again to retry the upload.'))
            : file.readStream ??
                (file.bytes == null
                    ? file.xFile.openRead()
                    : Stream.value(file.bytes!));
        item.attempted = true;
        item.uploaded = await GoogleDriveService(client).uploadRoomMedia(
            token: token,
            folderId: folder,
            filename: file.name,
            mimeType: mime,
            size: file.size,
            uploadKey: item.uploadKey,
            bytes: bytes,
            onProgress: (value) {
              if (mounted) setState(() => _progress = value);
            });
      }
      return [..._saved, ..._files.map((item) => item.uploaded!)];
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      rethrow;
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          _busy = false;
          _uploading = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Photos and videos',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
            'Files upload to your Google Drive when you save. You can include viewing links when sharing room details.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: widget.enabled && !_busy ? _pick : null,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Choose photos / videos')),
        for (final media in _saved)
          _fileRow(media.name, media.isVideo,
              () => setState(() => _saved.remove(media)),
              saved: true),
        for (final item in _files)
          _fileRow(
              item.file.name,
              RoomMediaModel.mimeTypes[item.file.extension?.toLowerCase()]
                      ?.startsWith('video/') ??
                  false,
              () => setState(() => _files.remove(item)),
              saved: item.uploaded != null),
        if (_busy) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _uploading == null ? null : _progress),
          Text(_uploading == null
              ? 'Selecting files…'
              : 'Uploading $_uploading · ${(_progress * 100).round()}%'),
        ],
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
      ]);

  Widget _fileRow(String name, bool video, VoidCallback remove,
          {required bool saved}) =>
      ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(video ? Icons.videocam_outlined : Icons.image_outlined),
          title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(saved
              ? 'Saved in Drive'
              : video
                  ? 'Video'
                  : 'Photo'),
          trailing: IconButton(
              tooltip: 'Remove attachment',
              icon: const Icon(Icons.close),
              onPressed: widget.enabled && !_busy ? remove : null));
}

class RoomMediaGallery extends StatelessWidget {
  final RoomModel room;
  const RoomMediaGallery({super.key, required this.room});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (room.media.isNotEmpty) ...[
          Text('Photos and videos',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final media in room.media)
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(media.isVideo
                    ? Icons.play_circle_outline
                    : Icons.image_outlined),
                title: Text(media.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () async {
                  try {
                    final opened = await launchUrl(Uri.parse(media.viewUrl),
                        mode: LaunchMode.externalApplication);
                    if (!opened) {
                      throw StateError('Could not open the file in Drive.');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Could not open the file in Drive.')));
                    }
                  }
                }),
        ],
        OutlinedButton.icon(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(room.media.isEmpty
                ? 'Add photos / videos'
                : 'Manage photos / videos'),
            onPressed: () => showRoomMediaEditor(context, room)),
      ]);
}

Future<void> showRoomMediaEditor(BuildContext context, RoomModel room) async {
  final repository = context.read<ManagementRepository>();
  final picker = GlobalKey<RoomMediaPickerState>();
  var saving = false;
  String? error;
  await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
          builder: (context, update) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                  title: Text('${room.roomNumber} · Photos and videos'),
                  content: SizedBox(
                      width: 480,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            RoomMediaPicker(
                                key: picker,
                                initialMedia: room.media,
                                enabled: !saving),
                            if (error != null)
                              Text(error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: saving ? null : () => Navigator.pop(context),
                        child: const Text('Close')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                update(() {
                                  saving = true;
                                  error = null;
                                });
                                try {
                                  final media = await picker.currentState!
                                      .uploadSelected();
                                  final latest = (await repository.getRooms())
                                      .where((value) =>
                                          value.roomId == room.roomId)
                                      .firstOrNull;
                                  if (latest == null) {
                                    throw StateError(
                                        'This room has been removed.');
                                  }
                                  await repository
                                      .updateRoom(RoomModel.fromJson({
                                    ...latest.toJson(),
                                    'media_json': [
                                      ...latest.media.where((value) =>
                                          !room.media.any((original) =>
                                              original.fileId == value.fileId)),
                                      ...media,
                                    ].map((value) => value.toJson()).toList()
                                  }));
                                  if (context.mounted) Navigator.pop(context);
                                } catch (exception) {
                                  if (context.mounted) {
                                    update(() {
                                      saving = false;
                                      error = exception.toString();
                                    });
                                  }
                                }
                              },
                        child: Text(saving ? 'Saving…' : 'Save media')),
                  ],
                ),
              )));
}
