import 'package:bed_space/data/models/bed_model.dart';
import 'package:bed_space/data/models/booking_model.dart';
import 'package:bed_space/data/models/tenant_model.dart';
import 'package:bed_space/data/repositories/management_repository.dart';
import 'package:bed_space/presentation/blocs/management/management_bloc.dart';
import 'package:bed_space/presentation/blocs/room/room_bloc.dart';
import 'package:bed_space/presentation/screens/bookings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'property_financials_test.dart' as fixtures;

class _Repository extends Fake implements ManagementRepository {
  BookingModel? saved;
  Map<String, dynamic>? data;
  @override
  Stream<Map<String, dynamic>> getAllDataStream() => Stream.value(data!);
  @override
  Future<void> addBooking(BookingModel booking) async => saved = booking;
}

class _Bloc extends ManagementBloc {
  _Bloc(ManagementRepository repository, ManagementLoaded data)
      : super(repository: repository) {
    emit(data);
  }
}

void main() {
  test(
      'room occupancy excludes reserved upper and lower beds from availability',
      () async {
    final today = BookingModel.day(DateTime.now());
    final repository = _Repository()
      ..data = {
        'buildings': fixtures.buildings,
        'rooms': fixtures.spaces,
        'tenants': <TenantModel>[],
        'beds': [
          for (final type in BedType.values)
            BedModel(
                bedId: type.name,
                roomId: 'parent',
                bedType: type,
                status: BedStatus.vacant),
        ],
        'bookings': [
          for (final type in BedType.values)
            BookingModel(
                bookingId: type.name,
                tenantName: 'Booked ${type.name}',
                phone: '050123',
                buildingId: 'b1',
                roomId: 'parent',
                bedId: type.name,
                moveInDate: today,
                rentAmount: 1000,
                advanceAmount: 0,
                rentPaid: 0,
                paymentDate: today,
                rentDueDay: 1),
        ],
      };
    final bloc = RoomBloc(repository: repository);
    bloc.add(const RoomLoadRequested());
    final loaded = await bloc.stream.firstWhere((state) => state is RoomsLoaded)
        as RoomsLoaded;
    final room = loaded.roomsByBuilding['b1']!
        .firstWhere((room) => room.room.roomId == 'parent');
    expect(room.vacantLowerBeds, 0);
    expect(room.vacantUpperBeds, 0);
    await bloc.close();
  });
  for (final size in [const Size(360, 800), const Size(1440, 1000)]) {
    for (final occupied in [false, true]) {
      testWidgets('Book a ${occupied ? 'departing' : 'vacant'} bed at $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
        final bloc = _Bloc(
            repository,
            ManagementLoaded(
                buildings: fixtures.buildings,
                rooms: fixtures.spaces,
                beds: [
                  BedModel(
                      bedId: 'bed',
                      roomId: 'parent',
                      bedType: BedType.lower,
                      status: occupied ? BedStatus.occupied : BedStatus.vacant)
                ],
                tenants: occupied
                    ? [
                        TenantModel.fromJson({
                          ...fixtures.tenants.first.toJson(),
                          'bed_id': 'bed',
                          'checkout_date': BookingModel.day(DateTime.now())
                              .toIso8601String(),
                        })
                      ]
                    : []));
        addTearDown(bloc.close);
        await tester.pumpWidget(Provider<ManagementRepository>.value(
            value: repository,
            child: BlocProvider<ManagementBloc>.value(
                value: bloc,
                child: const MaterialApp(home: BookingsScreen()))));
        await tester.tap(find.text('Book a bed'));
        await tester.pumpAndSettle();
        // TextFormField exposes its decoration through the descendant TextField.
        Finder input(String label) => find.byWidgetPredicate((widget) =>
            widget is TextField && widget.decoration?.labelText == label);
        await tester.enterText(input('Tenant name'), 'Future Tenant');
        await tester.enterText(input('Phone number'), '0501234567');
        final dropdown = find.byType(DropdownButtonFormField<String>);
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('lower 1').last);
        await tester.pumpAndSettle();
        for (final pair in [
          ('Monthly rent (AED)', '1000'),
          ('Advance received (AED)', '200'),
          ('Rent received for move-in month (AED)', '500'),
        ]) {
          await tester.ensureVisible(input(pair.$1));
          await tester.enterText(input(pair.$1), pair.$2);
        }
        await tester.tap(find.text('Save booking'));
        await tester.pumpAndSettle();
        expect(repository.saved?.tenantName, 'Future Tenant');
        expect(repository.saved?.advanceAmount, 200);
        expect(repository.saved?.rentPaid, 500);
        expect(repository.saved?.bedId, 'bed');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
