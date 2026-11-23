import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/google_token_store.dart';
import '../../data/services/saas_service.dart';

class WorkspaceBackupTile extends StatelessWidget {
  const WorkspaceBackupTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.backup_outlined),
      title: const Text('Automatic backups'),
      subtitle: const Text('Refresh the Backup spreadsheet every seven days'),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => const _BackupDialog(),
      ),
    );
  }
}

class _BackupDialog extends StatefulWidget {
  const _BackupDialog();

  @override
  State<_BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<_BackupDialog> {
  Map<String, dynamic>? _status;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load('status');
  }

  Future<Map<String, dynamic>> _request(String action) async {
    final body = <String, dynamic>{'action': action};
    if (action == 'enable') {
      final owner = SaasService.userId;
      final token =
          owner == null ? null : await GoogleTokenStore.readRefreshToken(owner);
      if (token == null || token.isEmpty || owner != SaasService.userId) {
        throw const FormatException('Reconnect Google and try again.');
      }
      body['refresh_token'] = token;
    }
    final response = await SaasService.client.functions
        .invoke('workspace-backups', body: body)
        .timeout(const Duration(seconds: 45));
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> _load(String action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var status = await _request(action);
      if (action == 'enable') status = await _request('status');
      if (mounted) setState(() => _status = status);
    } on FunctionException catch (error) {
      final details = error.details;
      if (mounted) {
        setState(() => _error = details is Map && details['error'] is String
            ? details['error'] as String
            : 'Could not reach the backup service.');
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not reach the backup service.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _date(BuildContext context, String key) {
    final value = _status?[key];
    final date = value is String ? DateTime.tryParse(value)?.toLocal() : null;
    if (date == null) return null;
    final format = MaterialLocalizations.of(context);
    final time = format.formatTimeOfDay(TimeOfDay.fromDateTime(date));
    return '${format.formatMediumDate(date)} at $time';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _status?['enabled'] == true;
    final last = _date(context, 'last_backup_at');
    final next = _date(context, 'next_backup_at');
    final problem = _status?['last_error'] as String?;
    final fileId = _status?['last_file_id'] as String?;
    return AlertDialog(
      title: const Text('Automatic backups'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Refresh the Backup spreadsheet in My Drive with your latest '
            'workspace data every seven days, even when the app is closed.',
          ),
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (enabled && last == null) const Text('First backup pending'),
          if (last != null) Text('Last backup $last'),
          if (fileId != null)
            TextButton(
              onPressed: () => launchUrl(
                Uri.https('docs.google.com', '/spreadsheets/d/$fileId/edit'),
              ),
              child: const Text('Open Backup'),
            ),
          if (last != null && next != null && problem == null)
            Text('Next backup due $next'),
          if (problem != null) Text(problem),
          if (_error != null) Text(_error!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (enabled && problem != null)
          TextButton(
            onPressed: _loading ? null : () => _load('enable'),
            child: const Text('Update Google connection'),
          ),
        TextButton(
          onPressed: _loading
              ? null
              : () => _load(_status == null
                  ? 'status'
                  : enabled
                      ? 'disable'
                      : 'enable'),
          child: Text(_status == null
              ? 'Retry'
              : enabled
                  ? 'Disable'
                  : 'Enable'),
        ),
      ],
    );
  }
}
