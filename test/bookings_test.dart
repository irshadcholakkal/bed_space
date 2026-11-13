import 'dart:convert';
import 'dart:io';
import 'package:bed_space/data/models/bed_model.dart';
import 'package:bed_space/data/models/booking_model.dart';
import 'package:bed_space/data/models/expense_model.dart';
import 'package:bed_space/data/models/property_financials.dart';
import 'package:bed_space/data/models/room_model.dart';
import 'package:bed_space/data/models/tenant_model.dart';
import 'package:bed_space/data/repositories/sync_worker.dart';
import 'package:bed_space/data/services/google_sheets_service.dart';
import 'package:bed_space/data/services/local_database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Sheets extends GoogleSheetsService {
  _Sheets() : super(accessToken: '', sheetId: '');
  final calls = <String>[];
  bool failBed = false;
  @override
  Future<void> saveBooking(BookingModel booking) async =>
      calls.add('booking:${booking.status.name}');
  @override
  Future<void> addTenant(TenantModel tenant) async =>
      calls.add('tenant:${tenant.tenantId}');
  @override
  Future<void> addPayment(payment) async =>
      calls.add('payment:${payment.paymentId}');
  @override
  Future<void> addExpense(ExpenseModel expense) async =>
      calls.add('refund:${expense.id}');
  @override
  Future<void> updateBedStatus(String bedId, BedStatus status) async {
    if (failBed) throw StateError('Offline');
    calls.add('bed:${status.name}');
  }
}

void main() {
  late Directory directory;
  late LocalDatabaseService local;
  var sequence = 0;
  final today = BookingModel.day(DateTime.now());
  final room = RoomModel.fromJson(
      {'room_id': 'room', 'building_id': 'building', 'room_number': '101'});
  final vacant = BedModel(
      bedId: 'bed',
      roomId: 'room',
      bedType: BedType.lower,
      status: BedStatus.vacant);
  BookingModel booking({String id = 'booking', DateTime? date}) => BookingModel(
      bookingId: id,
      tenantName: 'New tenant',
      phone: '0501234567',
      buildingId: 'building',
      roomId: 'room',
      bedId: 'bed',
      moveInDate: date ?? today,
      rentAmount: 1000,
      advanceAmount: 200,
      rentPaid: 500,
      paymentDate: today,
      rentDueDay: 1);
  TenantModel occupant({DateTime? checkout}) => TenantModel(
      tenantId: 'old',
      tenantName: 'Current tenant',
      phone: '050123',
      buildingId: 'building',
      roomId: 'room',
      bedId: 'bed',
      rentAmount: 1000,
      advanceAmount: 100,
      joiningDate: today.subtract(const Duration(days: 30)),
      rentDueDay: 1,
      active: true,
      checkoutDate: checkout);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bedspace_booking_');
    await databaseFactory.setDatabasesPath(directory.path);
    await LocalDatabaseService.selectWorkspace('booking_test_${sequence++}');
    local = LocalDatabaseService();
    await local.saveRooms([room]);
    await local.saveBeds([vacant]);
  });
  tearDown(() async {
    await (await local.database).close();
    await directory.delete(recursive: true);
  });

  Future<void> commitTenant(TenantModel tenant) => local.commitMutation({
        'id': 'tenant_mutation_${sequence++}',
        'type': 'UPDATE_TENANT',
        'payload': jsonEncode(tenant.toJson()),
        'timestamp': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });

  test('vacant bed booking saves payments without occupying the bed', () async {
    await local.createBooking(booking());
    expect((await local.getBeds()).single.status, BedStatus.vacant);
    expect(await local.getTenants(), isEmpty);
    expect((await local.getPayments()).single.tenantId, 'booking');
    expect((await local.getBookings()).single.advanceAmount, 200);
    await expectLater(
        local.createBooking(booking(id: 'duplicate')), throwsStateError);
    expect(await local.getPayments(), hasLength(1));
    await expectLater(commitTenant(occupant()), throwsStateError);
    expect(await local.getTenants(), isEmpty);
  });

  test('version 8 workspaces retain existing tenants when bookings are added',
      () async {
    await (await local.database).close();
    final workspace = 'booking_upgrade_${sequence++}';
    final path = '${directory.path}/bed_space_legacy_$workspace.db';
    final legacy =
        await openDatabase(path, version: 8, onCreate: (db, version) async {
      await db.execute('CREATE TABLE rooms(room_id TEXT PRIMARY KEY)');
      await db.execute(
          'CREATE TABLE tenants(tenant_id TEXT PRIMARY KEY, tenant_name TEXT)');
      await db.insert(
          'tenants', {'tenant_id': 'legacy', 'tenant_name': 'Existing tenant'});
    });
    await legacy.close();
    await LocalDatabaseService.selectWorkspace(workspace);
    local = LocalDatabaseService();
    expect((await local.getTenants()).single.tenantName, 'Existing tenant');
    expect(await local.getBookings(), isEmpty);
    expect(await (await local.database).getVersion(), 10);
  });

  test(
      'occupied bed accepts the scheduled checkout date and blocks early overlap',
      () async {
    final departure = today.add(const Duration(days: 35));
    await commitTenant(occupant());
    await expectLater(
        local.createBooking(booking(date: departure)), throwsStateError);
    await commitTenant(occupant(checkout: departure));
    await expectLater(
        local.createBooking(
            booking(date: departure.subtract(const Duration(days: 1)))),
        throwsStateError);
    await local.createBooking(booking(date: departure));
    expect((await local.getBeds()).single.status, BedStatus.occupied);
    expect((await local.getTenants()).single.tenantId, 'old');
    await expectLater(
        commitTenant(
            occupant(checkout: departure.add(const Duration(days: 1)))),
        throwsStateError);
    await expectLater(local.checkInBooking('booking'), throwsStateError);
  });

  test('check-in waits for explicit checkout and preserves money exactly once',
      () async {
    await commitTenant(occupant(checkout: today));
    await local.createBooking(booking());
    await expectLater(local.checkInBooking('booking'), throwsStateError);
    await commitTenant(occupant(checkout: today).copyWith(active: false));
    await local.checkInBooking('booking');
    final active =
        (await local.getTenants()).singleWhere((tenant) => tenant.active);
    expect(active.tenantId, 'booking');
    expect(active.advanceAmount, 200);
    expect((await local.getBeds()).single.status, BedStatus.occupied);
    expect(await local.getPayments(), hasLength(1));
    expect((await local.getBookings()).single.status, BookingStatus.checkedIn);
    await expectLater(local.checkInBooking('booking'), throwsStateError);
    expect(await local.getPayments(), hasLength(1));
  });

  test(
      'cancellation releases the reservation and records an optional refund once',
      () async {
    await local.createBooking(booking());
    await expectLater(local.cancelBooking('booking', 701), throwsArgumentError);
    await local.cancelBooking('booking', 700);
    expect((await local.getBookings()).single.status, BookingStatus.cancelled);
    expect((await local.getExpenses()).single.amount, 700);
    expect((await local.getBeds()).single.status, BedStatus.vacant);
    await expectLater(local.cancelBooking('booking', 700), throwsStateError);
    await local.createBooking(booking(id: 'replacement'));
    expect(await local.getExpenses(), hasLength(1));
  });

  test('booking rent appears in property totals before and after check-in once',
      () async {
    await local.createBooking(booking());
    Future<double> income() async => PropertyFinancials(
            rooms: [room],
            tenants: await local.getTenants(),
            bookings: await local.getBookings(),
            payments: await local.getPayments(),
            expenses: await local.getExpenses())
        .totals({'room'}).income;
    expect(await income(), 500);
    await local.checkInBooking('booking');
    expect(await income(), 500);
  });

  test('compound Sheets mutations retry partial check-ins with stable IDs',
      () async {
    final sheets = _Sheets();
    final worker = SyncWorker();
    Future<bool> run(String type, Map<String, dynamic> payload) =>
        worker.processMutation({
          'type': type,
          'payload': jsonEncode(payload),
        }, sheets);
    expect(await run('ADD_BOOKING', booking().toJson()), isTrue);
    expect(sheets.calls, ['booking:reserved', 'payment:booking_rent_booking']);
    sheets.calls.clear();
    sheets.failBed = true;
    expect(
        await run('CHECK_IN_BOOKING',
            booking().withStatus(BookingStatus.checkedIn).toJson()),
        isFalse);
    sheets.failBed = false;
    expect(
        await run('CHECK_IN_BOOKING',
            booking().withStatus(BookingStatus.checkedIn).toJson()),
        isTrue);
    expect(sheets.calls, [
      'tenant:booking',
      'tenant:booking',
      'bed:occupied',
      'booking:checkedIn'
    ]);
  });
}
