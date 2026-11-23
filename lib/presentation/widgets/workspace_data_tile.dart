import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/management_repository.dart';
import '../../data/services/workspace_data_service.dart';
import '../../data/services/workspace_report.dart';
import '../../data/services/workspace_report_files.dart';

class WorkspaceDataTile extends StatelessWidget {
  final String sheetId;
  const WorkspaceDataTile({super.key, required this.sheetId});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.folder_open_outlined),
        title: const Text('Download and restore data'),
        subtitle:
            const Text('Export readable reports or recover workspace records'),
        onTap: () => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _WorkspaceDataDialog(
            service: WorkspaceDataService(sheetId),
            repository: context.read<ManagementRepository>(),
          ),
        ),
      );
}

class _WorkspaceDataDialog extends StatefulWidget {
  final WorkspaceDataService service;
  final ManagementRepository repository;
  const _WorkspaceDataDialog({required this.service, required this.repository});

  @override
  State<_WorkspaceDataDialog> createState() => _WorkspaceDataDialogState();
}

class _WorkspaceDataDialogState extends State<_WorkspaceDataDialog> {
  bool _busy = false;
  String? _message;

  Future<void> _work(Future<void> Function() action) async {
    setState(() {
      _message = null;
      _busy = true;
    });
    try {
      await action();
    } on FormatException {
      _show('Choose a valid Bed Space recovery JSON file.');
    } on WorkspaceDataException catch (error) {
      _show(error.message);
    } catch (_) {
      _show('Could not complete the request. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (mounted) setState(() => _message = message);
  }

  Future<void> _save(String name, String extension, Uint8List bytes) async {
    if (!mounted) return;
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final selected = await FilePicker.platform.saveFile(
      dialogTitle: 'Save workspace data',
      fileName: '$name-$date.$extension',
      bytes: bytes,
    );
    if (kIsWeb || selected != null) _show('Download ready.');
  }

  Future<void> _downloadReport(WorkspaceReportFormat format) async {
    final result = await widget.service.call('report');
    final tables =
        workspaceReport(Map<String, dynamic>.from(result['tabs'] as Map));
    final bytes = await WorkspaceReportFiles.generate(tables, format);
    await _save('Bed-Space-Report', format.extension, bytes);
  }

  Future<Map<String, dynamic>> _recoveryFile({required bool weekly}) =>
      widget.service
          .call('recovery_file', fields: {'from_weekly_backup': weekly});

  Future<void> _downloadRecovery({required bool weekly}) async {
    final file = await _recoveryFile(weekly: weekly);
    await _save(weekly ? 'Bed-Space-Backup' : 'Bed-Space-Recovery', 'json',
        Uint8List.fromList(utf8.encode(jsonEncode(file))));
  }

  Future<void> _upload() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (selection == null) return;
    final bytes = selection.files.single.bytes;
    if (bytes == null) throw const FormatException();
    await _restore(jsonDecode(utf8.decode(bytes)), selection.files.single.name);
  }

  Future<void> _restore(Object? file, String source) async {
    final preview =
        await widget.service.call('preview_restore', fields: {'file': file});
    if (!mounted) return;
    final counts = Map<String, dynamic>.from(preview['counts'] as Map);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace live workspace data?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(source),
              const SizedBox(height: 12),
              const Text(
                'This replaces all workspace records with the data below. '
                'Records added since this backup may be lost. Ask anyone using '
                'the workspace to pause edits until the restore finishes.',
              ),
              const SizedBox(height: 12),
              for (final entry in counts.entries)
                Text('${entry.key}  ${entry.value}'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace workspace data')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final refreshed = await widget.repository.restoreWorkspace(() async {
      await widget.service.call('restore', fields: {'file': file});
    });
    _show(refreshed
        ? 'Workspace data restored.'
        : 'Workspace data restored in Google Sheets. The app will retry syncing.');
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: const Text('Download and restore data'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Download a workspace report',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final format in WorkspaceReportFormat.values)
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _work(() => _downloadReport(format)),
                        child: Text(format.label),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Recovery', style: Theme.of(context).textTheme.titleSmall),
                const Text(
                    'Use the weekly Backup spreadsheet or its recovery JSON file.'),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _work(() => _downloadRecovery(weekly: true)),
                  child: const Text('Download Backup recovery file'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _work(() => _downloadRecovery(weekly: false)),
                  child: const Text('Download current data recovery file'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _work(() async => _restore(
                          await _recoveryFile(weekly: true),
                          'Weekly Backup spreadsheet')),
                  child: const Text('Restore from weekly Backup'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _work(_upload),
                  child: const Text('Upload recovery file'),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_message!, semanticsLabel: _message),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
}
