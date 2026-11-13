import 'package:bed_space/data/models/bed_model.dart';
import 'package:bed_space/data/models/booking_model.dart';
import 'package:bed_space/data/models/building_model.dart';
import 'package:bed_space/data/models/room_model.dart';
import 'package:bed_space/data/models/tenant_model.dart';
import 'package:bed_space/data/repositories/management_repository.dart';
import 'package:bed_space/presentation/blocs/dashboard/dashboard_bloc.dart';
import 'package:bed_space/presentation/blocs/management/management_bloc.dart';
import 'package:bed_space/presentation/screens/vacant_beds_screen.dart';
import 'package:bed_space/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends Fake implements ManagementRepository {
  @override
  Stream<Map<String, dynamic>> getAllDataStream() => Stream.value({
        'buildings': _data.buildings,
        'rooms': _data.rooms,
        'beds': _data.beds,
        'tenants': _data.tenants,
        'bookings': _data.bookings,
        'payments': _data.payments,
        'expenses': _data.expenses,
      });
}

class _Bloc extends ManagementBloc {
  _Bloc() : super(repository: _Repository()) {
    emit(_data);
  }
}

RoomModel _room(String id, String number,
        {String building = 'a', String? parent, bool available = true}) =>
    RoomModel.fromJson({
      'room_id': id,
      'building_id': building,
      'room_number': number,
      'parent_room_id': parent,
      'available': available ? 'TRUE' : 'FALSE',
      'lower_bed_rent': 500,
      'upper_bed_rent': 450,
    });

BedModel _bed(String id, String room,
        {BedType type = BedType.lower, BedStatus status = BedStatus.vacant}) =>
    BedModel(bedId: id, roomId: room, bedType: type, status: status);

final _data = ManagementLoaded(
  buildings: [
    BuildingModel(
        buildingId: 'a',
        buildingName: 'Al Nahda Residence',
        address: 'Sharjah',
        totalRooms: 6),
    BuildingModel(
        buildingId: 'b',
        buildingName: 'Marina Residence',
        address: 'Dubai',
        totalRooms: 1),
  ],
  rooms: [
    _room('main', '101'),
    _room('sub', 'A', parent: 'main'),
    _room('marina', '201', building: 'b'),
    _room('full', '102'),
    _room('reserved', '103'),
    _room('stale', '104'),
    _room('closed', '105', available: false),
    _room('closed-child', 'B', parent: 'closed'),
  ],
  beds: [
    _bed('lower', 'main'),
    _bed('upper', 'main', type: BedType.upper),
    _bed('occupied', 'main', status: BedStatus.occupied),
    _bed('sub', 'sub', type: BedType.upper),
    _bed('marina', 'marina'),
    _bed('full', 'full', status: BedStatus.occupied),
    _bed('reserved', 'reserved'),
    _bed('stale', 'stale'),
    _bed('closed', 'closed'),
    _bed('closed-child', 'closed-child'),
  ],
  tenants: [
    TenantModel.fromJson(
        {'tenant_id': 'active', 'bed_id': 'stale', 'active': 'TRUE'})
  ],
  bookings: [
    BookingModel(
        bookingId: 'booking',
        tenantName: 'Booked tenant',
        phone: '050123',
        buildingId: 'a',
        roomId: 'reserved',
        bedId: 'reserved',
        moveInDate: DateTime(2030),
        rentAmount: 500,
        advanceAmount: 0,
        rentPaid: 0,
        paymentDate: DateTime(2026),
        rentDueDay: 1)
  ],
);

void main() {
  test('dashboard availability counts all eligible rooms once', () async {
    final bloc = DashboardBloc(repository: _Repository());
    bloc.add(const DashboardLoadRequested());
    final result = await bloc.stream
        .firstWhere((state) => state is DashboardLoaded) as DashboardLoaded;
    expect(result.availableRooms, 3);
    expect(result.vacantBeds, 4);
    await bloc.close();
  });

  for (final (size, textScale) in const [
    (Size(320, 640), 1.0),
    (Size(390, 844), 1.0),
    (Size(740, 360), 1.0),
    (Size(1440, 900), 1.0),
    (Size(320, 640), 1.5),
  ]) {
    testWidgets(
        'all available rooms and bed actions fit $size at $textScale text scale',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bloc = _Bloc();
      addTearDown(bloc.close);
      await tester.pumpWidget(BlocProvider<ManagementBloc>.value(
          value: bloc,
          child: MaterialApp(
              theme: AppTheme.theme,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!),
              home: const VacantBedsScreen())));
      await tester.pumpAndSettle();
      expect(find.text('3 rooms · 4 beds available'), findsOneWidget);
      expect(find.text('All buildings'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('available-room-marina')), 200,
          scrollable: scrollable);
      expect(find.text('Room 201'), findsOneWidget);
      await tester.dragUntilVisible(
          find.byKey(const ValueKey('available-room-main')),
          scrollable,
          const Offset(0, 250));
      await tester.ensureVisible(find.text('Choose a bed').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a bed').first);
      await tester.pumpAndSettle();
      expect(find.text('Lower bed 1'), findsOneWidget);
      expect(find.text('Upper bed 1'), findsOneWidget);
      expect(find.text('Room 101'), findsOneWidget);
      final bookButtons = find.widgetWithText(FilledButton, 'Book');
      expect(bookButtons, findsNWidgets(2));
      for (final button in bookButtons.evaluate()) {
        expect(tester.getSize(find.byWidget(button.widget)).height,
            greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('search and filters can return to every available room',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bloc = _Bloc();
    addTearDown(bloc.close);
    await tester.pumpWidget(BlocProvider<ManagementBloc>.value(
        value: bloc,
        child: MaterialApp(
            theme: AppTheme.theme, home: const VacantBedsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upper beds'));
    await tester.pumpAndSettle();
    expect(find.text('2 rooms · 2 beds available'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Marina');
    await tester.pumpAndSettle();
    expect(find.text('No matching rooms'), findsOneWidget);
    await tester.ensureVisible(find.text('Show all available rooms'));
    await tester.tap(find.text('Show all available rooms'));
    await tester.pumpAndSettle();
    expect(find.text('3 rooms · 4 beds available'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marina Residence').last);
    await tester.pumpAndSettle();
    expect(find.text('1 room · 1 bed available'), findsOneWidget);
    expect(find.text('Room 201'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
