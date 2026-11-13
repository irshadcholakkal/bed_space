import 'dart:convert';
import 'dart:io';

import 'package:bed_space/data/models/bed_model.dart';
import 'package:bed_space/data/models/tenant_model.dart';
import 'package:bed_space/data/services/local_database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late LocalDatabaseService local;
  late Directory directory;
  var sequence = 0;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    directory = await Directory.systemTemp.createTemp('occupancy_sync_');
    await databaseFactory.setDatabasesPath(directory.path);
    await LocalDatabaseService.selectWorkspace('test_${sequence++}');
    local = LocalDatabaseService();
    await local.saveBeds([
      BedModel(
          bedId: 'old',
          roomId: 'room',
          bedType: BedType.lower,
          status: BedStatus.vacant),
      BedModel(
          bedId: 'new',
          roomId: 'room',
          bedType: BedType.upper,
          status: BedStatus.vacant),
    ]);
  });

  tearDown(() async {
    await (await local.database).close();
    await directory.delete(recursive: true);
  });

  TenantModel tenant({String bed = 'old', bool active = true}) => TenantModel(
      tenantId: 'tenant',
      tenantName: 'Tenant',
      phone: '',
      buildingId: 'building',
      roomId: 'room',
      bedId: bed,
      rentAmount: 100,
      advanceAmount: 0,
      joiningDate: DateTime(2026, 11, 1),
      rentDueDay: 1,
      active: active);

  Future<void> commit(String type, Map<String, dynamic> payload) =>
      local.commitMutation({
        'id': 'mutation_${sequence++}',
        'type': type,
        'payload': jsonEncode(payload),
        'timestamp': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });

  Future<void> clearQueue() async {
    for (final item in await local.getMutationQueue()) {
      await local.removeFromQueue(item['id'] as String);
    }
  }

  test('tenant lifecycle commits occupancy and Sheets retry records together',
      () async {
    await commit('ADD_TENANT', tenant().toJson());
    expect((await local.getBeds()).first.status, BedStatus.occupied);
    final queue = await local.getMutationQueue();
    expect(
        queue.map((item) => item['type']), ['ADD_TENANT', 'UPDATE_BED_STATUS']);
    expect(jsonDecode(queue.last['payload'] as String)['status'],
        'BedStatus.occupied');

    await commit('UPDATE_TENANT', tenant(bed: 'new').toJson());
    final transferred = await local.getBeds();
    expect(transferred.first.status, BedStatus.vacant);
    expect(transferred.last.status, BedStatus.occupied);

    await commit('UPDATE_TENANT', tenant(bed: 'new', active: false).toJson());
    expect(
        (await local.getBeds()).every((bed) => bed.status == BedStatus.vacant),
        isTrue);
    await commit('UPDATE_TENANT', tenant().toJson());
    await commit('DELETE_TENANT', {'id': 'tenant'});
    expect(await local.getTenants(), isEmpty);
    expect((await local.getBeds()).first.status, BedStatus.vacant);
  });

  test('pending writes and intervening writes reject stale remote snapshots',
      () async {
    final revision = local.revision;
    await commit('ADD_TENANT', tenant().toJson());
    final empty = [[], [], <TenantModel>[], [], <BedModel>[], []];
    await local.saveSnapshot(empty, expectedRevision: local.revision);
    expect(await local.getTenants(), hasLength(1));
    await clearQueue();
    await local.saveSnapshot(empty, expectedRevision: revision);
    expect(await local.getTenants(), hasLength(1));
    expect((await local.getBeds()).first.status, BedStatus.occupied);
  });

  test(
      'legacy active tenants repair vacant beds and persist a Sheets correction',
      () async {
    final beds = await local.getBeds();
    await local.saveSnapshot([
      [],
      [],
      [tenant()],
      [],
      beds,
      []
    ], expectedRevision: local.revision);
    expect((await local.getBeds()).first.status, BedStatus.occupied);
    expect(
        (await local.getMutationQueue()).single['type'], 'UPDATE_BED_STATUS');
  });

  test('conflicting occupancy rolls back the tenant and queue', () async {
    await commit('ADD_TENANT', tenant().toJson());
    await clearQueue();
    await expectLater(
        commit('ADD_TENANT', tenant().copyWith(tenantId: 'other').toJson()),
        throwsStateError);
    expect(await local.getTenants(), hasLength(1));
    expect(await local.getMutationQueue(), isEmpty);
  });
}
