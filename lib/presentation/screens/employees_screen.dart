import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/employee_service.dart';
import '../../data/services/saas_service.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _run(() async {});
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      final data = await EmployeeService.call('members');
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is EmployeeRequestException
            ? error.message
            : 'Employee access is unavailable. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? member]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EmployeePermissionsDialog(member: member),
    );
    if (result == null || !mounted) return;
    await _run(() async {
      await EmployeeService.call(member == null ? 'invite' : 'update', {
        ...result,
        if (member != null) 'id': member['id'],
      });
    });
  }

  Future<void> _remove(Map<String, dynamic> member) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove employee access?'),
        content: Text('${member['email']} will lose access to this workspace.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove access'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await _run(() async {
      await EmployeeService.call('remove', {'id': member['id']});
    });
  }

  Future<void> _copyLink() async {
    final link =
        Uri.parse(SaasService.authRedirectUrl).resolve('employee-workspaces');
    await Clipboard.setData(ClipboardData(text: link.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Link copied. Share it with the invited employee.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? const <String, dynamic>{};
    final members = EmployeeService.rows(data, 'members');
    final activity = EmployeeService.rows(data, 'activity')
        .where((entry) => entry['completed_at'] != null);
    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      body: RefreshIndicator(
        onRefresh: () => _busy ? Future.value() : _run(() async {}),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      _busy || data['connected'] != true ? null : () => _edit(),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Invite employee'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _run(EmployeeService.connect),
                  child: Text(data['connected'] == true
                      ? 'Reconnect Google'
                      : 'Connect Google for employees'),
                ),
                TextButton(
                  onPressed: () => context.push('/employee-workspaces'),
                  child: const Text('Employee workspaces'),
                ),
              ],
            ),
            if (data['connected'] != true && !_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                    'Connect your Google account so employees can work from your private spreadsheet.'),
              ),
            for (final member in members)
              Card(
                child: ListTile(
                  title: Text('${member['email']}'),
                  subtitle: Text([
                    member['employee_id'] == null ? 'Pending' : 'Active',
                    for (final key in member['permissions'] as List)
                      employeePermissions[key],
                  ].whereType<String>().join(' · ')),
                  trailing: PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (choice) {
                      switch (choice) {
                        case 'edit':
                          _edit(member);
                        case 'copy':
                          _copyLink();
                        case 'remove':
                          _remove(member);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit permissions')),
                      if (member['employee_id'] == null)
                        const PopupMenuItem(
                            value: 'copy', child: Text('Copy invitation link')),
                      const PopupMenuItem(
                          value: 'remove', child: Text('Remove access')),
                    ],
                  ),
                ),
              ),
            if (activity.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Recent activity',
                  style: Theme.of(context).textTheme.titleLarge),
              for (final entry in activity)
                ListTile(
                  title: Text(
                      '${entry['employee_email']} · ${_activityLabel(entry)}'),
                  subtitle: Text(_activityDetails(entry)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _activityDetails(Map<String, dynamic> entry) {
    final details = entry['details'] as Map;
    final date = DateTime.parse(entry['completed_at'] as String)
        .toUtc()
        .add(const Duration(hours: 4))
        .toIso8601String()
        .substring(0, 10);
    return [
      date,
      if (details['amount'] != null) 'AED ${details['amount']}',
      if (entry['action'] == 'collect') 'Payment ${entry['operation_id']}',
      if (details['payment'] != null) 'Payment ${details['payment']}',
      if (details['reason'] != null) '${details['reason']}',
    ].join(' · ');
  }

  String _activityLabel(Map<String, dynamic> entry) =>
      switch (entry['action']) {
        'collect' => 'Recorded rent',
        'void_payment' => 'Voided payment',
        'book' => 'Created a booking',
        'check_in' => 'Checked in a tenant',
        'check_out' => 'Checked out a tenant',
        'assign_bed' => 'Changed a bed assignment',
        _ => 'Updated the workspace',
      };
}

class _EmployeePermissionsDialog extends StatefulWidget {
  final Map<String, dynamic>? member;
  const _EmployeePermissionsDialog({this.member});

  @override
  State<_EmployeePermissionsDialog> createState() =>
      _EmployeePermissionsDialogState();
}

class _EmployeePermissionsDialogState
    extends State<_EmployeePermissionsDialog> {
  late final _selected =
      (widget.member?['permissions'] as List? ?? ['occupancy'])
          .cast<String>()
          .toSet();
  String _email = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            widget.member == null ? 'Invite employee' : 'Edit permissions'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.member == null)
                  TextField(
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: 'Email address'),
                    onChanged: (value) => setState(() => _email = value.trim()),
                  ),
                for (final permission in employeePermissions.entries)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(permission.value),
                    value: _selected.contains(permission.key),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selected.add(permission.key);
                        if (permission.key == 'void_payments') {
                          _selected.add('payment_history');
                        }
                      } else {
                        _selected.remove(permission.key);
                        if (permission.key == 'payment_history') {
                          _selected.remove('void_payments');
                        }
                      }
                    }),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: _selected.isEmpty ||
                    (widget.member == null && !_email.contains('@'))
                ? null
                : () => Navigator.pop(context, {
                      'email': _email,
                      'permissions': _selected.toList(),
                    }),
            child: Text(widget.member == null ? 'Create invitation' : 'Save'),
          ),
        ],
      );
}
