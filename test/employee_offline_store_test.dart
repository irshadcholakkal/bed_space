// The platform package provides the official in-memory preferences test double.
// ignore_for_file: depend_on_referenced_packages

import 'package:bed_space/data/services/employee_offline_store.dart';
import 'package:bed_space/data/services/employee_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('offline snapshots and changes are isolated by employee and workspace',
      () async {
    final store = EmployeeOfflineStore('employee');
    await store.saveSnapshot('workspace', {
      'permissions': ['collect_rent'],
    });
    final id = await store.enqueue('workspace', 'collect', {'amount': 100});
    final reopened = EmployeeOfflineStore('employee');
    expect((await reopened.snapshot('workspace'))?['permissions'],
        ['collect_rent']);
    expect((await reopened.changes('workspace')).single['id'], id);
    expect(await reopened.changes('another-workspace'), isEmpty);
    final otherAccount = EmployeeOfflineStore('another-employee');
    expect(await otherAccount.snapshot('workspace'), isNull);
    expect(await otherAccount.changes('workspace'), isEmpty);
    await reopened.reconcileWorkspaces([]);
    expect(await reopened.snapshot('workspace'), isNull);
    final rejected = (await reopened.changes('workspace')).single;
    expect(rejected['state'], 'rejected');
    expect(rejected['error'], 'Workspace access was removed.');
  });

  test('retry reuses the queued payment ID and keeps its confirmed receipt',
      () async {
    final store = EmployeeOfflineStore('employee');
    final id = await store.enqueue('workspace', 'collect', {'amount': 100});
    final reopen = EmployeeOfflineStore('employee');
    await expectLater(
      reopen.replay('workspace',
          isSignedIn: () => true,
          send: (action, fields) async {
            expect(action, 'collect');
            expect(fields['operation'], id);
            throw const EmployeeRequestException('Offline', status: 0);
          }),
      throwsA(isA<EmployeeRequestException>()),
    );

    expect((await reopen.changes('workspace')).single['state'], 'pending');
    await reopen.replay('workspace',
        isSignedIn: () => true,
        send: (_, fields) async {
          expect(fields['operation'], id);
          return {'receipt': id};
        });

    final item = (await reopen.changes('workspace')).single;
    expect(item['state'], 'confirmed');
    expect(item['receipt'], id);
    expect(
      await reopen.replay('workspace',
          isSignedIn: () => true,
          send: (_, __) async => throw StateError('Already confirmed')),
      isFalse,
    );
  });

  test(
      'permission and conflicts are checked at replay without dropping changes',
      () async {
    final store = EmployeeOfflineStore('employee');
    await store.enqueue('workspace', 'book', {'bed': 'already-reserved'});
    await store.replay('workspace',
        isSignedIn: () => false,
        send: (_, __) async => throw StateError('Wrong account'));
    expect((await store.changes('workspace')).single['state'], 'pending');
    await store.replay('workspace',
        isSignedIn: () => true,
        send: (_, __) async {
          throw const EmployeeRequestException('Bed reserved', status: 409);
        });
    final item = (await store.changes('workspace')).single;
    expect(item['state'], 'rejected');
    expect(item['error'], 'Bed reserved');
    expect(
        EmployeeOfflineStore.canUseCache(
            const EmployeeRequestException('Access denied', status: 403)),
        isFalse);
  });
}
