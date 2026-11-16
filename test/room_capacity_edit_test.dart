import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bed_space/data/models/room_model.dart';
import 'package:bed_space/data/models/bed_model.dart';
import 'package:bed_space/data/services/local_database_service.dart';

RoomModel room(int lower, int upper, {RoomType type = RoomType.bedspace}) =>
    RoomModel(
        roomId: 'room',
        buildingId: 'building',
        roomNumber: '101',
        roomType: type,
        totalCapacity: lower + upper,
        lowerBedsCount: lower,
        upperBedsCount: upper,
        lowerBedRent: 700,
        upperBedRent: 600,
        utilityCostMonthly: 0);

void main() {
  late LocalDatabaseService local;
  late Directory directory;
  var sequence = 0;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('room_capacity_');
    await databaseFactory.setDatabasesPath(directory.path);
    await LocalDatabaseService.selectWorkspace('capacity_${sequence++}');
    local = LocalDatabaseService();
    await local.saveRooms([room(1, 1)]);
    await local.saveBeds([
      BedModel(
          bedId: 'lower',
          roomId: 'room',
          bedType: BedType.lower,
          status: BedStatus.vacant),
      BedModel(
          bedId: 'upper',
          roomId: 'room',
          bedType: BedType.upper,
          status: BedStatus.vacant),
    ]);
  });
  tearDown(() async {
    await (await local.database).close();
    await directory.delete(recursive: true);
  });

  test(
      'editing capacity creates and removes real spaces with durable sync records',
      () async {
    await local.updateRoomCapacity(room(2, 0));
    final beds = await local.getBeds();
    expect(beds, hasLength(2));
    expect(beds.every((bed) => bed.bedType == BedType.lower), isTrue);
    expect(beds.any((bed) => bed.bedId == 'lower'), isTrue);
    final queue = await (await local.database).query('mutation_queue');
    expect(queue.map((row) => row['type']),
        containsAll(['UPDATE_ROOM', 'DELETE_BED', 'ADD_BED']));
  });
  test('occupied bed cannot be removed and the entire edit rolls back',
      () async {
    await local.upsertBed(BedModel(
        bedId: 'upper',
        roomId: 'room',
        bedType: BedType.upper,
        status: BedStatus.occupied));
    await expectLater(local.updateRoomCapacity(room(1, 0)), throwsStateError);
    expect((await local.getRooms()).single.totalCapacity, 2);
    expect(await local.getBeds(), hasLength(2));
    expect(await (await local.database).query('mutation_queue'), isEmpty);
  });
  test('reserved space cannot be removed', () async {
    await (await local.database).insert('bookings',
        {'booking_id': 'booking', 'bed_id': 'upper', 'status': 'reserved'});
    await expectLater(local.updateRoomCapacity(room(1, 0)), throwsStateError);
    expect((await local.getRooms()).single.totalCapacity, 2);
  });
  for (final type in [
    RoomType.partition,
    RoomType.studio,
    RoomType.wholeRoom
  ]) {
    test('${type.label} persists as a single rentable unit', () async {
      await local.updateRoomCapacity(room(1, 0, type: type));
      final restored = (await local.getRooms()).single;
      expect(restored.roomType, type);
      expect(restored.totalCapacity, 1);
      expect(restored.lowerBedRent, 700);
      expect(await local.getBeds(), hasLength(1));
      expect(RoomModel.fromJson(restored.toJson()).roomType, type);
    });
  }
}
