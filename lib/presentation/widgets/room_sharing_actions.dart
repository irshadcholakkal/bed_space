import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../../data/models/bed_model.dart';
import '../../data/models/room_model.dart';
import '../../data/models/room_media_model.dart';
import '../../data/repositories/sheet_repository.dart';
import '../../data/services/google_drive_service.dart';
import '../../data/services/status_message_service.dart';
import '../blocs/management/management_bloc.dart';

Future<void> openRoomShare(BuildContext context, RoomModel room) async {
  final state = context.read<ManagementBloc>().state;
  if (state is! ManagementLoaded) return;
  final latest =
      state.rooms.where((value) => value.roomId == room.roomId).firstOrNull ??
          room;
  final building = state.buildings
      .where((value) => value.buildingId == latest.buildingId)
      .firstOrNull;
  final occupied = state.tenants
      .where((tenant) => tenant.active)
      .map((tenant) => tenant.bedId)
      .toSet();
  final reserved = state.reservedBedIds;
  final beds = state.beds.where((bed) =>
      bed.roomId == latest.roomId &&
      bed.status == BedStatus.vacant &&
      !occupied.contains(bed.bedId) &&
      !reserved.contains(bed.bedId) &&
      latest.isAvailable(state.rooms));
  await showRoomShareDraft(context,
      message: StatusMessageService.roomDetails(
          room: latest,
          rooms: state.rooms,
          building: building?.buildingName ?? latest.buildingId,
          address: building?.address ?? '',
          lowerAvailable:
              beds.where((bed) => bed.bedType == BedType.lower).length,
          upperAvailable:
              beds.where((bed) => bed.bedType == BedType.upper).length),
      media: latest.media);
}

Future<void> showRoomShareDraft(BuildContext context,
    {required String message, List<RoomMediaModel> media = const []}) async {
  var selected = <RoomMediaModel>[];
  if (media.isNotEmpty) {
    final result = await showDialog<List<RoomMediaModel>>(
        context: context, builder: (_) => _RoomMediaShareDialog(media: media));
    if (result == null || !context.mounted) return;
    selected = result;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RoomShareDraft(
          message: message + StatusMessageService.roomMediaLinks(selected)));
}

class _RoomShareDraft extends StatefulWidget {
  final String message;
  const _RoomShareDraft({required this.message});
  @override
  State<_RoomShareDraft> createState() => _RoomShareDraftState();
}

class _RoomShareDraftState extends State<_RoomShareDraft> {
  late final _text = TextEditingController(text: widget.message);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _share(BuildContext buttonContext) async {
    if (_text.text.trim().isEmpty) {
      setState(() => _error = 'Enter the room details to share.');
      return;
    }
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SharePlus.instance.share(ShareParams(
          text: _text.text,
          title: 'Room details',
          subject: 'Room details',
          sharePositionOrigin: origin,
          mailToFallbackEnabled: false,
          downloadFallbackEnabled: false));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Sharing is unavailable here. Copy the room details and paste them into your preferred app.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
          child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Text('Share room details',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                    controller: _text,
                    enabled: !_busy,
                    minLines: 6,
                    maxLines: 12,
                    decoration: const InputDecoration(labelText: 'Message')),
                const SizedBox(height: 12),
                const Text(
                    'Choose an app and recipient from your device’s share menu.'),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              try {
                                await Clipboard.setData(
                                    ClipboardData(text: _text.text));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Room details copied')));
                                }
                              } catch (_) {
                                if (mounted) {
                                  setState(() => _error =
                                      'Select the message text to copy it manually.');
                                }
                              }
                            },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy details')),
                  Builder(
                      builder: (buttonContext) => FilledButton.icon(
                          onPressed: _busy ? null : () => _share(buttonContext),
                          icon: const Icon(Icons.share_outlined),
                          label: Text(_busy
                              ? 'Opening share menu…'
                              : 'Share with apps'))),
                ]),
              ]))));
}

class _RoomMediaShareDialog extends StatefulWidget {
  final List<RoomMediaModel> media;
  const _RoomMediaShareDialog({required this.media});
  @override
  State<_RoomMediaShareDialog> createState() => _RoomMediaShareDialogState();
}

class _RoomMediaShareDialogState extends State<_RoomMediaShareDialog> {
  late final _selected = widget.media.map((media) => media.fileId).toSet();
  bool _busy = false;
  String? _error;

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = http.Client();
    try {
      final media = widget.media
          .where((media) => _selected.contains(media.fileId))
          .toList();
      if (media.isNotEmpty) {
        final token = await SheetRepository().getToken();
        if (token == null) {
          throw StateError('Reconnect Google to share room media.');
        }
        final drive = GoogleDriveService(client);
        for (final item in media) {
          await drive.enableMediaLinkViewing(token: token, fileId: item.fileId);
        }
      }
      if (mounted) Navigator.pop(context, media);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Share room media'),
        content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  const Text(
                      'Select photos and videos to include with the room details. Selected files become viewable by anyone with their links.'),
                  const SizedBox(height: 12),
                  for (final media in widget.media)
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _selected.contains(media.fileId),
                        secondary: Icon(media.isVideo
                            ? Icons.videocam_outlined
                            : Icons.image_outlined),
                        title: Text(media.name,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(media.fileId);
                                  } else {
                                    _selected.remove(media.fileId);
                                  }
                                })),
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                ]))),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Close')),
          FilledButton(
              onPressed: _busy ? null : _continue,
              child:
                  Text(_busy ? 'Preparing links…' : 'Review sharing message')),
        ],
      ));
}
