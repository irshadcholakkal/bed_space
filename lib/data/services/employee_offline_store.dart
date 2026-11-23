import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'employee_service.dart';

class EmployeeOfflineStore {
  final String account;
  final SharedPreferencesAsync _preferences;

  EmployeeOfflineStore(this.account, {SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  String get _prefix => 'employee.offline.$account.';
  String _snapshotKey(String workspace) => '${_prefix}snapshot.$workspace';
  String _changePrefix(String workspace) => '${_prefix}change.$workspace.';

  Future<Map<String, dynamic>?> _read(String key) async {
    final value = await _preferences.getString(key);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> snapshot(String workspace) =>
      _read(_snapshotKey(workspace));

  Future<void> saveSnapshot(String workspace, Map<String, dynamic> data) =>
      _preferences.setString(_snapshotKey(workspace), jsonEncode(data));

  Future<void> clearSnapshot(String workspace) =>
      _preferences.remove(_snapshotKey(workspace));

  Future<void> reconcileWorkspaces(List<Map<String, dynamic>> active) async {
    final permissions = {
      for (final workspace in active)
        workspace['id']: (workspace['permissions'] as List).toSet(),
    };
    final prefix = '${_prefix}snapshot.';
    for (final key in await _preferences.getKeys()) {
      if (!key.startsWith(prefix) || key == _snapshotKey('list')) continue;
      final id = key.substring(prefix.length);
      final granted = permissions[id];
      if (granted == null) {
        await clearSnapshot(id);
        await rejectPending(id, 'Workspace access was removed.');
      } else {
        final cached = await snapshot(id);
        final saved = (cached?['permissions'] as List? ?? const []).toSet();
        if (!granted.containsAll(saved)) await clearSnapshot(id);
      }
    }
  }

  Future<List<Map<String, dynamic>>> changes(String workspace) async {
    final prefix = _changePrefix(workspace);
    final keys = await _preferences.getKeys();
    final queued = (await Future.wait(
      keys.where((key) => key.startsWith(prefix)).map(_read),
    ))
        .whereType<Map<String, dynamic>>()
        .toList();
    queued.sort((first, second) =>
        (first['created'] as int).compareTo(second['created'] as int));
    return queued;
  }

  Future<String> enqueue(
    String workspace,
    String action,
    Map<String, dynamic> fields,
  ) async {
    final id = const Uuid().v4();
    await saveChange(workspace, {
      'id': id,
      'action': action,
      'fields': fields,
      'state': 'pending',
      'created': DateTime.now().microsecondsSinceEpoch,
    });
    return id;
  }

  Future<void> saveChange(String workspace, Map<String, dynamic> change) =>
      _preferences.setString(
          '${_changePrefix(workspace)}${change['id']}', jsonEncode(change));

  Future<void> removeChange(String workspace, String id) =>
      _preferences.remove('${_changePrefix(workspace)}$id');

  Future<void> rejectPending(String workspace, String reason) async {
    for (final change in await changes(workspace)) {
      if (change['state'] == 'pending') {
        await saveChange(
            workspace, {...change, 'state': 'rejected', 'error': reason});
      }
    }
  }

  static bool canUseCache(Object error) {
    if (error is! EmployeeRequestException) return false;
    final status = error.status;
    return status == 0 || status == 429 || (status != null && status >= 500);
  }

  Future<bool> replay(
    String workspace, {
    required bool Function() isSignedIn,
    required Future<Map<String, dynamic>> Function(
            String action, Map<String, dynamic> fields)
        send,
  }) async {
    var changed = false;
    for (final change in await changes(workspace)) {
      if (!isSignedIn()) break;
      if (change['state'] != 'pending') continue;
      changed = true;
      final action = change['action'] as String;
      final id = change['id'] as String;
      try {
        final result = await send(action, {
          ...change['fields'] as Map<String, dynamic>,
          'workspace': workspace,
          'operation': id,
        });
        if (action == 'collect') {
          await saveChange(workspace,
              {...change, 'state': 'confirmed', 'receipt': result['receipt']});
        } else {
          await removeChange(workspace, id);
        }
      } on EmployeeRequestException catch (error) {
        if (canUseCache(error) || error.status == 401) rethrow;
        await saveChange(workspace,
            {...change, 'state': 'rejected', 'error': error.message});
      }
    }
    return changed;
  }
}
