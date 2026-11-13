import 'dart:async';
import 'dart:convert';

import 'package:bed_space/data/models/bed_model.dart';
import 'package:bed_space/data/models/building_model.dart';
import 'package:bed_space/data/models/room_model.dart';
import 'package:bed_space/data/repositories/management_repository.dart';
import 'package:bed_space/data/services/google_sheets_service.dart';
import 'package:bed_space/presentation/blocs/management/management_bloc.dart';
import 'package:bed_space/presentation/screens/rooms_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

RoomModel room(String id, String name,
        {String? parent, String building = 'building'}) =>
    RoomModel(
      roomId: id,
      buildingId: building,
      roomNumber: name,
      parentRoomId: parent,
      totalCapacity: 2,
      lowerBedsCount: 1,
      upperBedsCount: 1,
      lowerBedRent: 650,
      upperBedRent: 600,
      utilityCostMonthly: 0,
    );

class RoomRepository extends Fake implements ManagementRepository {
  final List<RoomModel> rooms;
  final beds = <BedModel>[];
  final bedsCreated = Completer<void>();
  bool deleted = false;
  RoomModel? addedRoom;
  RoomRepository(this.rooms);

  @override
  Future<RoomModel> addRoom(RoomModel value) async {
    addedRoom = value;
    return rooms.last;
  }

  @override
  Future<void> triggerSync() async {}
  @override
  Future<List<BuildingModel>> getBuildings({bool forceRefresh = false}) async =>
      [building];
  @override
  Future<List<RoomModel>> getRooms({bool forceRefresh = false}) async => rooms;
  @override
  Future<List<BedModel>> getBeds({bool forceRefresh = false}) async => beds;
  @override
  Future<void> addBed(BedModel value) async {
    beds.add(value);
    if (beds.length == 2) bedsCreated.complete();
  }

  @override
  Future<void> deleteRoom(String id) async {
    deleted = true;
  }

  @override
  Future<void> deleteBed(String id) async {
    deleted = true;
  }
}

final building = BuildingModel(
    buildingId: 'building',
    buildingName: 'Test Building',
    address: '',
    totalRooms: 1);

class SeededManagementBloc extends ManagementBloc {
  SeededManagementBloc(RoomRepository repository)
      : super(repository: repository) {
    emit(ManagementLoaded(rooms: repository.rooms, buildings: [building]));
  }
}

void main() {
  final parent = room('parent', '101');
  final child = room('child', 'A', parent: 'parent');

  testWidgets('Add Subroom preselects the parent and saves its association',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = RoomRepository([parent]);
    final bloc = SeededManagementBloc(repository);
    await tester.pumpWidget(MaterialApp(
        home: BlocProvider<ManagementBloc>.value(
            value: bloc, child: const RoomsManagementScreen())));
    await tester.tap(find.byTooltip('Add Subroom'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Inside room (optional)'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Subroom Number / Name'), 'B');
    await tester
        .ensureVisible(find.widgetWithText(ElevatedButton, 'Add Subroom'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Subroom'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.addedRoom?.parentRoomId, 'parent');
    expect(repository.addedRoom?.buildingId, 'building');
    expect(repository.addedRoom?.roomNumber, 'B');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => bloc.close());
  });

  test('legacy rooms and subrooms survive JSON storage', () {
    final legacy = Map<String, dynamic>.from(parent.toJson())
      ..remove('parent_room_id');
    expect(RoomModel.fromJson(legacy).isSubroom, isFalse);
    expect(RoomModel.fromJson({...legacy, 'parent_room_id': ''}).parentRoomId,
        isNull);
    expect(RoomModel.fromJson(child.toJson()).parentRoomId, 'parent');
    expect(child.displayName([parent, child]), 'Room 101 / Subroom A');
  });

  test('hierarchy rejects invalid parents, cycles and moves with children', () {
    child.validateHierarchy([parent]);
    for (final invalid in [
      room('child', 'A', parent: 'missing'),
      room('child', 'A', parent: 'child'),
      room('nested', 'B', parent: 'child'),
      room('child', 'A', parent: 'parent', building: 'other'),
      room('parent', '101', building: 'other'),
    ]) {
      expect(() => invalid.validateHierarchy([parent, child]),
          throwsArgumentError);
    }
  });

  test('subroom names can repeat under different parents', () {
    final otherParent = room('other', '102');
    room('new', 'A', parent: 'other')
        .validateHierarchy([parent, child, otherParent]);
    expect(
        () => room('new', ' a ', parent: 'parent')
            .validateHierarchy([parent, child]),
        throwsArgumentError);
  });

  test('beds attach to the returned room ID when subroom names repeat',
      () async {
    final repository = RoomRepository(
        [parent, child, room('new-child', 'A', parent: 'other')]);
    final bloc = ManagementBloc(repository: repository);
    bloc.add(AddRoom(room('', 'A', parent: 'other')));
    await repository.bedsCreated.future.timeout(const Duration(seconds: 5));
    expect(repository.beds.map((bed) => bed.roomId), everyElement('new-child'));
    await bloc.close();
  });

  test('deleting a parent is rejected before any bed deletion', () async {
    final repository = RoomRepository([parent, child]);
    final bloc = ManagementBloc(repository: repository);
    final failure = bloc.stream.firstWhere(
        (state) => state is ManagementLoaded && state.error != null);
    bloc.add(const DeleteRoom('parent'));
    expect((await failure as ManagementLoaded).error, contains('subrooms'));
    expect(repository.deleted, isFalse);
    await bloc.close();
  });

  test('Sheets reads legacy rows and stores parent IDs in column K', () async {
    final writes = <http.Request>[];
    final service = GoogleSheetsService(accessToken: 'test', sheetId: 'test');
    await http.runWithClient(() async {
      final rooms = await service.getRooms();
      expect(rooms.first.parentRoomId, isNull);
      await service.addRoom(child);
      await service.updateRoom(child);
      await service.deleteRoom('child');
    },
        () => MockClient((request) async {
              if (request.url.queryParameters['fields'] ==
                  'sheets.properties') {
                return http.Response(
                    jsonEncode({
                      'sheets': [
                        {
                          'properties': {
                            'title': 'Rooms',
                            'sheetId': 1,
                            'gridProperties': {'columnCount': 13}
                          }
                        }
                      ]
                    }),
                    200);
              }
              if (request.method == 'GET') {
                return http.Response(
                    jsonEncode({
                      'values': [
                        [
                          'child',
                          'building',
                          'A',
                          '2',
                          '1',
                          '1',
                          '650',
                          '600',
                          '0',
                          '0'
                        ],
                      ]
                    }),
                    200);
              }
              writes.add(request);
              return http.Response('{}', 200);
            }));
    final rows = writes
        .map((request) =>
            (jsonDecode(request.body)['values'] as List).first as List)
        .where((row) => row.length > 2)
        .toList();
    expect(rows[0][10], 'parent');
    expect(rows[1][10], 'parent');
    expect(rows[2], everyElement(''));
    expect(rows[2], hasLength(13));
    expect(rows[0][11], 'TRUE');
  });
}
