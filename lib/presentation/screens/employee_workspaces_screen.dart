import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/employee_service.dart';
import '../../data/services/employee_offline_store.dart';
import '../../data/services/offline_status.dart';
import '../../data/services/saas_service.dart';
import '../routing/app_routes.dart';

class EmployeeWorkspacesScreen extends StatefulWidget {
  const EmployeeWorkspacesScreen({super.key});

  @override
  State<EmployeeWorkspacesScreen> createState() =>
      _EmployeeWorkspacesScreenState();
}

class _EmployeeWorkspacesScreenState extends State<EmployeeWorkspacesScreen> {
  late Future<Map<String, dynamic>> _workspaces;

  @override
  void initState() {
    super.initState();
    _workspaces = _loadWorkspaces();
    AppSessionRoute.save(SaasService.userId, '/employee-workspaces');
  }

  Future<Map<String, dynamic>> _loadWorkspaces() async {
    final store = EmployeeOfflineStore(SaasService.userId!);
    Map<String, dynamic> data;
    try {
      if (await isDeviceOffline()) {
        throw const EmployeeRequestException('You are offline.', status: 0);
      }
      data = await EmployeeService.call('workspaces');
      if (SaasService.userId != store.account) {
        throw const EmployeeRequestException('Sign in to continue.',
            status: 401);
      }
    } catch (error) {
      if (error is EmployeeRequestException && error.status == 403) {
        try {
          await store.reconcileWorkspaces([]);
          await store.clearSnapshot('list');
        } catch (_) {
          // Show the access error even when browser storage is unavailable.
        }
      }
      if (!EmployeeOfflineStore.canUseCache(error)) rethrow;
      final cached = await store.snapshot('list');
      if (cached == null) rethrow;
      return {...cached, 'offline': true};
    }
    try {
      final active = EmployeeService.rows(data, 'workspaces')
          .where((workspace) => workspace['pending'] != true)
          .toList();
      await store.reconcileWorkspaces(active);
      await store.saveSnapshot('list', {'workspaces': active});
    } catch (_) {
      // The online list remains available with browser storage disabled.
    }
    return data;
  }

  Future<void> _refresh() async {
    final request = _loadWorkspaces();
    setState(() => _workspaces = request);
    try {
      await request;
    } catch (_) {
      // FutureBuilder shows the request error.
    }
  }

  Future<void> _open(Map<String, dynamic> workspace) async {
    if (workspace['pending'] == true) {
      try {
        await EmployeeService.call('accept', {'id': workspace['id']});
      } catch (error) {
        if (mounted) _notice(context, _errorText(error));
        return;
      }
      if (mounted) _refresh();
    }
    if (!mounted) return;
    await context.push('/employee-workspaces/${workspace['id']}',
        extra: workspace['name'] as String?);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Employee workspaces'),
          actions: [
            TextButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('My workspace'),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => SaasService.client.auth.signOut(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _workspaces,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final workspaces =
                EmployeeService.rows(snapshot.data ?? {}, 'workspaces');
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  if (snapshot.data?['offline'] == true)
                    const Text('Offline. Showing saved workspaces.'),
                  if (snapshot.hasError) Text(_errorText(snapshot.error)),
                  if (!snapshot.hasError && workspaces.isEmpty)
                    const Text(
                        'No invitations for this account. Sign in with the email your employer invited.'),
                  for (final workspace in workspaces)
                    Card(
                      child: ListTile(
                        title: Text('${workspace['name']}'),
                        trailing: FilledButton(
                          onPressed: () => _open(workspace),
                          child: Text(
                              workspace['pending'] == true ? 'Join' : 'Open'),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
}

String _errorText(Object? error) => error is EmployeeRequestException
    ? error.message
    : 'Employee access is unavailable. Check your connection and try again.';

void _notice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

String _day() => DateTime.now()
    .toUtc()
    .add(const Duration(hours: 4))
    .toIso8601String()
    .substring(0, 10);

class EmployeeWorkspaceScreen extends StatefulWidget {
  final String workspaceId;
  final String? initialName;
  const EmployeeWorkspaceScreen(
      {super.key, required this.workspaceId, this.initialName});

  @override
  State<EmployeeWorkspaceScreen> createState() => _EmployeeWorkspaceState();
}

class _EmployeeWorkspaceState extends State<EmployeeWorkspaceScreen> {
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _changes = [];
  late final EmployeeOfflineStore _store;
  StreamSubscription<List<ConnectivityResult>>? _connection;
  Timer? _retryTimer;
  String? _error;
  bool _busy = true;
  bool _refreshing = false;
  bool _offline = false;

  String get _workspace => widget.workspaceId;
  String get _name => widget.initialName ?? 'Employee workspace';

  @override
  void initState() {
    super.initState();
    _store = EmployeeOfflineStore(SaasService.userId!);
    AppSessionRoute.save(
        SaasService.userId, '/employee-workspaces/$_workspace');
    _connection = Connectivity().onConnectivityChanged.listen((_) {
      if (mounted && !_busy) unawaited(_refresh());
    }, onError: (Object _) {});
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          !_busy &&
          (_offline ||
              _changes.any((change) => change['state'] == 'pending'))) {
        unawaited(_refresh());
      }
    });
    _refresh();
  }

  @override
  void dispose() {
    _connection?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    setState(() {
      _busy = true;
      _error = null;
    });
    Map<String, dynamic>? data;
    var offline = false;
    String? errorText;
    try {
      if (await isDeviceOffline()) {
        throw const EmployeeRequestException('You are offline.', status: 0);
      }
      var latest =
          await EmployeeService.call('data', {'workspace': _workspace});
      if (SaasService.userId != _store.account) {
        throw const EmployeeRequestException('Sign in to continue.',
            status: 401);
      }
      try {
        if (await _store.replay(_workspace,
            isSignedIn: () => SaasService.userId == _store.account,
            send: EmployeeService.call)) {
          latest =
              await EmployeeService.call('data', {'workspace': _workspace});
        }
      } catch (error) {
        if (!EmployeeOfflineStore.canUseCache(error)) rethrow;
        offline = true;
        errorText = _errorText(error);
      }
      if (SaasService.userId != _store.account) {
        throw const EmployeeRequestException('Sign in to continue.',
            status: 401);
      }
      try {
        await _store.saveSnapshot(_workspace, latest);
      } catch (_) {
        errorText = 'Offline storage is unavailable in this browser.';
      }
      data = latest;
    } catch (error) {
      errorText = _errorText(error);
      offline = EmployeeOfflineStore.canUseCache(error);
      data = null;
      try {
        if (offline) {
          data = await _store.snapshot(_workspace);
          if (data == null) {
            errorText = 'Open this workspace online first to use it offline.';
          }
        }
        if (error is EmployeeRequestException &&
            (error.status == 401 || error.status == 403)) {
          await _store.clearSnapshot(_workspace);
          if (error.status == 403) {
            await _store.rejectPending(_workspace, error.message);
          }
        }
      } catch (_) {
        errorText = 'Offline storage is unavailable in this browser.';
      }
    } finally {
      _refreshing = false;
      if (mounted) {
        List<Map<String, dynamic>> changes = [];
        try {
          changes = await _store.changes(_workspace);
        } catch (_) {
          errorText = 'Offline storage is unavailable in this browser.';
        }
        if (mounted && SaasService.userId == _store.account) {
          setState(() {
            _data = data;
            _busy = false;
            _error = errorText;
            _offline = offline;
            _changes = changes;
          });
        }
      }
    }
  }

  Future<void> _save(String action, Map<String, dynamic> fields) async {
    if (_busy || SaasService.userId != _store.account) return;
    setState(() => _busy = true);
    String id;
    try {
      id = await _store.enqueue(_workspace, action, fields);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _notice(context, 'This change could not be saved on this device.');
      }
      return;
    }
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    final matching = _changes.where((change) => change['id'] == id);
    if (matching.isEmpty) {
      if (action != 'collect' && _error == null) {
        _notice(context, 'Saved to Google Sheets.');
      }
    } else if (matching.first['state'] == 'confirmed') {
      await _openReceipt(matching.first);
    } else if (matching.first['state'] == 'pending') {
      _notice(
          context, 'Saved on this device. Waiting to sync to Google Sheets.');
    }
  }

  Future<void> _removeChange(String id) async {
    await _store.removeChange(_workspace, id);
    final updated = await _store.changes(_workspace);
    if (mounted) setState(() => _changes = updated);
  }

  Future<void> _openReceipt(Map<String, dynamic> change) async {
    final acknowledged =
        await _receipt(change, change['fields'] as Map<String, dynamic>);
    if (mounted && acknowledged == true) {
      await _removeChange(change['id'] as String);
    }
  }

  Future<bool?> _receipt(
      Map<String, dynamic> result, Map<String, dynamic> payment) async {
    final tenants = EmployeeService.rows(_data ?? {}, 'tenants');
    final tenant = tenants.where(
      (tenant) => '${tenant['id']}' == '${payment['tenant']}',
    );
    final text = [
      'Rent receipt',
      _name,
      if (tenant.isNotEmpty) '${tenant.first['name']}',
      'AED ${payment['amount']} for ${payment['month']}',
      'Paid on ${payment['date']}',
      'Payment reference ${result['receipt']}',
    ].join('\n');
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rent payment recorded'),
        content: SelectableText(text),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Copy receipt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _collect(Map<String, dynamic> tenant) async {
    final payment = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CollectRentDialog(
          workspace: _workspace, tenant: tenant, offline: _offline),
    );
    if (payment != null && mounted) await _save('collect', payment);
  }

  Future<void> _form(
    String title,
    String action,
    Map<String, dynamic> base,
    List<({String key, String label, String initial})> fields, {
    Map<String, String> beds = const {},
  }) async {
    final form = GlobalKey<FormState>();
    final values = <String, dynamic>{
      ...base,
      for (final field in fields) field.key: field.initial,
    };
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: form,
          child: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final field in fields)
                    TextFormField(
                      initialValue: field.initial,
                      decoration: InputDecoration(labelText: field.label),
                      onSaved: (value) => values[field.key] = value!.trim(),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                    ),
                  if (beds.isNotEmpty)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Bed'),
                      items: [
                        for (final entry in beds.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value,
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      validator: (value) =>
                          value == null ? 'Choose a bed' : null,
                      onChanged: (value) {},
                      onSaved: (value) => values['bed'] = value,
                    ),
                  if (fields.isEmpty && beds.isEmpty)
                    const Text('Confirm this change to the workspace.'),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              form.currentState!.save();
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) await _save(action, values);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? const <String, dynamic>{};
    final permissions =
        (data['permissions'] as List? ?? const []).cast<String>();
    final tenants = EmployeeService.rows(data, 'tenants');
    final rooms = EmployeeService.rows(data, 'rooms');
    final buildings = EmployeeService.rows(data, 'buildings');
    final beds = EmployeeService.rows(data, 'beds');
    final bookings = EmployeeService.rows(data, 'bookings');
    final payments = EmployeeService.rows(data, 'payments');
    final canBook = permissions.contains('bookings');
    final canCollect = permissions.contains('collect_rent');
    final canVoid = permissions.contains('void_payments');
    final canSeePayments = permissions.contains('payment_history');
    final canSeeOccupancy = canBook || permissions.contains('occupancy');
    final canSave = !_busy && _data != null;

    final buildingNames = {
      for (final building in buildings) '${building['id']}': building['name'],
    };
    final roomNames = {
      for (final room in rooms)
        '${room['id']}':
            '${buildingNames['${room['building']}'] ?? 'Building'} / ${room['name']}',
    };
    final reserved =
        (data['reserved_beds'] as List? ?? const []).map((id) => '$id').toSet();
    final bedNames = {
      for (final bed in beds)
        '${bed['id']}':
            '${roomNames['${bed['room']}'] ?? 'Room'} · ${bed['type']} · ${bed['id']}',
    };
    final vacant = {
      for (final bed in beds)
        if ('${bed['status']}'.toUpperCase() == 'VACANT' &&
            !reserved.contains('${bed['id']}'))
          '${bed['id']}': bedNames['${bed['id']}']!,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          if (!context.canPop())
            TextButton(
              onPressed: () => context.go('/employee-workspaces'),
              child: const Text('Workspaces'),
            ),
          IconButton(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh from Google Sheets',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _busy ? Future.value() : _refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (_offline && _data != null)
              const ListTile(
                leading: Icon(Icons.cloud_off),
                title: Text('Offline or Sheets unavailable'),
                subtitle: Text(
                    'Showing saved data. New changes will sync when the connection returns.'),
              ),
            for (final change in _changes)
              ListTile(
                title: Text(switch (change['state']) {
                  'confirmed' => 'Rent payment synced',
                  'rejected' => 'Change needs attention',
                  _ => change['action'] == 'collect'
                      ? 'Rent payment waiting to sync'
                      : 'Workspace change waiting to sync',
                }),
                subtitle: _changeDetails(change, canCollect),
                trailing: switch (change['state']) {
                  'confirmed' when canCollect => TextButton(
                      onPressed: () => _openReceipt(change),
                      child: const Text('View receipt')),
                  'rejected' => TextButton(
                      onPressed: () => _removeChange(change['id'] as String),
                      child: const Text('Dismiss')),
                  _ => null,
                },
              ),
            if (canBook) ...[
              FilledButton.icon(
                onPressed: !canSave || vacant.isEmpty
                    ? null
                    : () => _form(
                        'New booking',
                        'book',
                        {},
                        [
                          (key: 'name', label: 'Tenant name', initial: ''),
                          (key: 'phone', label: 'Phone number', initial: ''),
                          (
                            key: 'date',
                            label: 'Move-in date (YYYY-MM-DD)',
                            initial: _day()
                          ),
                        ],
                        beds: vacant),
                icon: const Icon(Icons.event_available),
                label: const Text('New booking'),
              ),
              _section('Upcoming bookings'),
              if (bookings.isEmpty) const Text('No reserved bookings.'),
              for (final booking in bookings)
                ListTile(
                  title: Text('${booking['name']}'),
                  subtitle: Text(
                      '${booking['date']} · ${bedNames['${booking['bed']}'] ?? ''}'),
                  trailing: TextButton(
                    onPressed: !canSave
                        ? null
                        : () => _form('Check in ${booking['name']}', 'check_in',
                            {'booking': booking['id']}, []),
                    child: const Text('Check in'),
                  ),
                ),
            ],
            if (canSeeOccupancy || canCollect) ...[
              _section('Active tenants'),
              if (tenants.isEmpty) const Text('No active tenants.'),
              for (final tenant in tenants)
                ListTile(
                  title: Text('${tenant['name']}'),
                  subtitle: tenant['bed'] == null
                      ? null
                      : Text(bedNames['${tenant['bed']}'] ??
                          'Bed assignment unavailable'),
                  trailing: canBook || canCollect
                      ? PopupMenuButton<String>(
                          enabled: canSave,
                          onSelected: (action) {
                            final base = {'tenant': tenant['id']};
                            switch (action) {
                              case 'collect':
                                _collect(tenant);
                              case 'assign_bed':
                                _form('Change bed assignment', action, base, [],
                                    beds: vacant);
                              case 'check_out':
                                _form('Check out ${tenant['name']}', action,
                                    {...base, 'date': _day()}, []);
                            }
                          },
                          itemBuilder: (_) => [
                            if (canCollect)
                              const PopupMenuItem(
                                  value: 'collect',
                                  child: Text('Collect rent')),
                            if (canBook)
                              PopupMenuItem(
                                enabled: vacant.isNotEmpty,
                                value: 'assign_bed',
                                child: const Text('Change bed'),
                              ),
                            if (canBook)
                              const PopupMenuItem(
                                  value: 'check_out', child: Text('Check out')),
                          ],
                        )
                      : null,
                ),
            ],
            if (canSeeOccupancy) ...[
              _section('Room and bed availability'),
              if (beds.isEmpty) const Text('No beds are configured.'),
              for (final room in rooms)
                ExpansionTile(
                  title: Text(roomNames['${room['id']}']!),
                  children: [
                    for (final bed
                        in beds.where((bed) => bed['room'] == room['id']))
                      ListTile(
                        title: Text('${bed['type']} · ${bed['id']}'),
                        trailing: Text(reserved.contains('${bed['id']}')
                            ? 'Reserved'
                            : '${bed['status']}'),
                      ),
                  ],
                ),
            ],
            if (canSeePayments) ...[
              _section('Payment history'),
              if (payments.isEmpty) const Text('No payments recorded.'),
              for (final payment in payments.reversed)
                ListTile(
                  title: Text(
                      'AED ${payment['amount']} · ${payment['tenant_name'] ?? payment['tenant']}'),
                  subtitle: Text('${payment['month']} · ${payment['date']}'),
                  trailing: canVoid
                      ? TextButton(
                          onPressed: !canSave
                              ? null
                              : () =>
                                  _form('Void rent payment', 'void_payment', {
                                    'payment': payment['id']
                                  }, [
                                    (
                                      key: 'reason',
                                      label: 'Reason',
                                      initial: ''
                                    ),
                                  ]),
                          child: const Text('Void'),
                        )
                      : null,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(label, style: Theme.of(context).textTheme.titleLarge),
      );

  Widget? _changeDetails(Map<String, dynamic> change, bool canCollect) {
    final fields = change['fields'] as Map;
    final details = [
      if (canCollect && change['action'] == 'collect')
        'AED ${fields['amount']} · ${fields['month']} · ${fields['date']}',
      if (change['error'] != null) change['error'] as String,
    ];
    return details.isEmpty ? null : Text(details.join('\n'));
  }
}

class _CollectRentDialog extends StatefulWidget {
  final String workspace;
  final Map<String, dynamic> tenant;
  final bool offline;
  const _CollectRentDialog(
      {required this.workspace, required this.tenant, required this.offline});

  @override
  State<_CollectRentDialog> createState() => _CollectRentDialogState();
}

class _CollectRentDialogState extends State<_CollectRentDialog> {
  final _month = TextEditingController(text: _day().substring(0, 7));
  final _date = TextEditingController(text: _day());
  final _amount = TextEditingController();
  String? _loadedMonth;
  String? _error;
  num? _due;
  bool _loading = false;
  bool _lookupUnavailable = false;

  @override
  void initState() {
    super.initState();
    if (!widget.offline) _loadDue();
  }

  @override
  void dispose() {
    _month.dispose();
    _date.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadDue() async {
    final month = _month.text.trim();
    setState(() {
      _loading = true;
      _error = null;
      _loadedMonth = null;
      _due = null;
    });
    try {
      final result = await EmployeeService.call('rent_due', {
        'workspace': widget.workspace,
        'tenant': '${widget.tenant['id']}',
        'month': month,
      });
      if (mounted && _month.text.trim() == month) {
        setState(() {
          _due = result['due'] as num;
          _loadedMonth = month;
          _lookupUnavailable = false;
          _amount.text = _due! > 0 ? _due!.toStringAsFixed(2) : '';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorText(error);
          _lookupUnavailable = EmployeeOfflineStore.canUseCache(error);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amount.text.trim());
    final manualAmount = widget.offline || _lookupUnavailable;
    final paidOn = _date.text.trim();
    final parsedDate = DateTime.tryParse(paidOn);
    final validDate =
        parsedDate?.toIso8601String().split('T').first == paidOn &&
            paidOn.compareTo(_day()) <= 0;
    return AlertDialog(
      title: Text('Collect rent for ${widget.tenant['name']}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _month,
                decoration: InputDecoration(
                  labelText: 'Rent month (YYYY-MM)',
                  suffixIcon: IconButton(
                    tooltip: 'Check amount due',
                    onPressed: _loading || widget.offline ? null : _loadDue,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (!_loading && !widget.offline) _loadDue();
                },
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) Text(_error!),
              if (manualAmount)
                const Text(
                    'The latest rent balance is unavailable. Enter the amount received. A receipt will be available after sync.'),
              if (_loadedMonth == _month.text.trim())
                Text('Amount due: AED ${_due!.toStringAsFixed(2)}'),
              TextField(
                controller: _amount,
                decoration:
                    const InputDecoration(labelText: 'Amount paid (AED)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _date,
                decoration:
                    const InputDecoration(labelText: 'Paid on (YYYY-MM-DD)'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ||
                  (!manualAmount && _loadedMonth != _month.text.trim()) ||
                  !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$')
                      .hasMatch(_month.text.trim()) ||
                  amount == null ||
                  !amount.isFinite ||
                  amount <= 0 ||
                  amount > 1000000 ||
                  (amount * 100 - (amount * 100).round()).abs() > 0.000001 ||
                  !validDate
              ? null
              : () => Navigator.pop(context, {
                    'tenant': '${widget.tenant['id']}',
                    'month': _month.text.trim(),
                    'amount': amount,
                    'date': paidOn,
                  }),
          child: Text(manualAmount ? 'Save payment' : 'Record payment'),
        ),
      ],
    );
  }
}
