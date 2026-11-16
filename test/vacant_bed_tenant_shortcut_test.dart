import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bed_space/data/models/bed_model.dart';
import 'package:bed_space/data/models/room_model.dart';
import 'package:bed_space/data/models/building_model.dart';
import 'package:bed_space/data/models/booking_model.dart';
import 'package:bed_space/data/repositories/management_repository.dart';
import 'package:bed_space/presentation/blocs/management/management_bloc.dart';
import 'package:bed_space/presentation/blocs/room/room_bloc.dart';
import 'package:bed_space/presentation/screens/room_occupancy_screen.dart';

class _Repository extends Fake implements ManagementRepository {}

final room = RoomModel(
    roomId: 'room',
    buildingId: 'building',
    roomNumber: '101',
    totalCapacity: 1,
    lowerBedsCount: 0,
    upperBedsCount: 1,
    lowerBedRent: 700,
    upperBedRent: 600,
    utilityCostMonthly: 0);
final stats = RoomWithStats(room: room, vacantLowerBeds: 0, vacantUpperBeds: 1);

class _Management extends ManagementBloc {
  _Management(BedModel bed) : super(repository: _Repository()) {
    emit(ManagementLoaded(rooms: [
      room
    ], beds: [
      bed
    ], buildings: [
      BuildingModel(
          buildingId: 'building',
          buildingName: 'Marina',
          address: '',
          totalRooms: 1),
    ]));
  }
  @override
  void add(ManagementEvent event) {}
}

class _Rooms extends RoomBloc {
  _Rooms(BedDetail detail) : super(repository: _Repository()) {
    emit(RoomsLoaded(roomsByBuilding: {
      'building': [stats]
    }, selectedRoomDetails: [
      detail
    ]));
  }
  @override
  void add(RoomEvent event) {}
}

void main() {
  for (final kind in ['vacant', 'occupied', 'reserved']) {
    testWidgets(
        '$kind bed shortcut only opens a preselected tenant form when available',
        (tester) async {
      tester.view.physicalSize = const Size(400, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bed = BedModel(
          bedId: 'bed',
          roomId: 'room',
          bedType: BedType.upper,
          status: kind == 'occupied' ? BedStatus.occupied : BedStatus.vacant);
      final detail = BedDetail(
          bed: bed,
          booking: kind == 'reserved'
              ? BookingModel.fromJson({
                  'booking_id': 'booking',
                  'tenant_name': 'Future tenant',
                  'room_id': 'room',
                  'bed_id': 'bed',
                  'status': 'reserved',
                  'move_in_date': '2026-12-01',
                  'payment_date': '2026-11-01'
                })
              : null);
      final management = _Management(bed);
      final rooms = _Rooms(detail);
      addTearDown(management.close);
      addTearDown(rooms.close);
      await tester.pumpWidget(MultiBlocProvider(
          providers: [
            BlocProvider<ManagementBloc>.value(value: management),
            BlocProvider<RoomBloc>.value(value: rooms),
          ],
          child: MaterialApp(
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () =>
                              showRoomDetailBottomSheet(context, stats),
                          child: const Text('Open')))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upper Bed'));
      await tester.pumpAndSettle();
      if (kind == 'vacant') {
        expect(find.widgetWithText(TextField, 'Tenant Name'), findsOneWidget);
        final dropdowns = tester.widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>));
        expect(dropdowns.map((field) => field.initialValue),
            containsAll(['building', 'room']));
        final rent = tester
            .widget<TextField>(find.widgetWithText(TextField, 'Monthly Rent'));
        expect(rent.controller!.text, '600');
        expect(
            tester
                .widget<ChoiceChip>(
                    find.widgetWithText(ChoiceChip, 'Upper (د.إ600)'))
                .selected,
            isTrue);
        expect(find.text('Bed Availability'), findsNothing);
      } else {
        expect(find.text('Bed Availability'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Tenant Name'), findsNothing);
        expect(find.text('Tap to add tenant'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
