import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/building_model.dart';
import '../models/room_model.dart';
import '../models/tenant_model.dart';
import '../models/payment_model.dart';
import '../models/bed_model.dart';
import '../models/expense_model.dart';
import '../models/booking_model.dart';
import 'saas_service.dart';

class LocalDatabaseService {
  static final Map<String?, LocalDatabaseService> _instances = {};
  Database? _database;
  final String? _scope;
  static String? _activeScope;

  static Future<void> selectWorkspace(String sheetId) async {
    final scope = '${SaasService.userId ?? 'legacy'}_$sheetId';
    _activeScope = scope.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  factory LocalDatabaseService() => _instances.putIfAbsent(
      _activeScope, () => LocalDatabaseService._internal(_activeScope));

  LocalDatabaseService._internal(this._scope);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final name = _scope == null ? 'bed_space.db' : 'bed_space_$_scope.db';
    final path = kIsWeb ? name : join(await getDatabasesPath(), name);
    return await openDatabase(
      path,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion >= 2 && oldVersion < 9) await _createBookings(db);
    if (oldVersion >= 2 && oldVersion < 8) {
      await db.execute(
          "ALTER TABLE rooms ADD COLUMN available TEXT NOT NULL DEFAULT 'TRUE'");
    }
    if (oldVersion >= 2 && oldVersion < 7) {
      await db.execute('ALTER TABLE rooms ADD COLUMN parent_room_id TEXT');
    }
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS buildings');
      await db.execute('DROP TABLE IF EXISTS rooms');
      await db.execute('DROP TABLE IF EXISTS tenants');
      await db.execute('DROP TABLE IF EXISTS payments');
      await db.execute('DROP TABLE IF EXISTS beds');
      await _onCreate(db, newVersion);
      return;
    } else if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE mutation_queue(
          id TEXT PRIMARY KEY,
          type TEXT,
          payload TEXT,
          timestamp TEXT,
          retry_count INTEGER
        )
      ''');
    }

    if (oldVersion < 4) {
      // Add expenses table
      await db.execute('''
        CREATE TABLE expenses(
          id TEXT PRIMARY KEY,
          room_id TEXT,
          expense_type TEXT,
          amount REAL,
          date TEXT,
          description TEXT
        )
      ''');

      // Add monthly_rent to rooms
      try {
        await db.execute(
            'ALTER TABLE rooms ADD COLUMN monthly_rent REAL DEFAULT 0.0');
      } catch (e) {
        developer.log('Error adding monthly_rent column: $e');
      }
    }

    if (oldVersion < 5) {
      // Add checkout_date to tenants
      try {
        await db.execute('ALTER TABLE tenants ADD COLUMN checkout_date TEXT');
      } catch (e) {
        developer.log('Error adding checkout_date column to tenants: $e');
      }
    }

    if (oldVersion < 6) {
      // Add tenant_id to expenses
      try {
        await db.execute('ALTER TABLE expenses ADD COLUMN tenant_id TEXT');
      } catch (e) {
        developer.log('Error adding tenant_id column to expenses: $e');
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createBookings(db);
    await db.execute('''
      CREATE TABLE buildings(
        building_id TEXT PRIMARY KEY,
        building_name TEXT,
        address TEXT,
        total_rooms INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE rooms(
        room_id TEXT PRIMARY KEY,
        building_id TEXT,
        room_number TEXT,
        total_capacity INTEGER,
        lower_beds_count INTEGER,
        upper_beds_count INTEGER,
        lower_bed_rent REAL,
        upper_bed_rent REAL,
        utility_cost_monthly REAL,
        monthly_rent REAL,
        parent_room_id TEXT,
        available TEXT NOT NULL DEFAULT 'TRUE'
      )
    ''');

    await db.execute('''
      CREATE TABLE tenants(
        tenant_id TEXT PRIMARY KEY,
        tenant_name TEXT,
        phone TEXT,
        building_id TEXT,
        room_id TEXT,
        bed_id TEXT,
        rent_amount REAL,
        advance_amount REAL,
        joining_date TEXT,
        rent_due_day INTEGER,
        active TEXT,
        checkout_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE payments(
        payment_id TEXT PRIMARY KEY,
        tenant_id TEXT,
        amount REAL,
        payment_month TEXT,
        paid_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE beds(
        bed_id TEXT PRIMARY KEY,
        room_id TEXT,
        bed_type TEXT,
        status TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE mutation_queue(
        id TEXT PRIMARY KEY,
        type TEXT,
        payload TEXT,
        timestamp TEXT,
        retry_count INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses(
        id TEXT PRIMARY KEY,
        room_id TEXT,
        tenant_id TEXT,
        expense_type TEXT,
        amount REAL,
        date TEXT,
        description TEXT
      )
    ''');
  }

  // --- Buildings ---
  Future<void> saveBuildings(List<BuildingModel> buildings) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('buildings');
      for (var building in buildings) {
        await txn.insert(
          'buildings',
          building.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<BuildingModel>> getBuildings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('buildings');
    return List.generate(maps.length, (i) => BuildingModel.fromJson(maps[i]));
  }

  Future<void> upsertBuilding(BuildingModel building) async {
    final db = await database;
    await db.insert(
      'buildings',
      building.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBuildingLocal(String id) async {
    final db = await database;
    await db.delete('buildings', where: 'building_id = ?', whereArgs: [id]);
  }

  // --- Rooms ---
  Future<void> saveRooms(List<RoomModel> rooms) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('rooms');
      for (var room in rooms) {
        await txn.insert(
          'rooms',
          room.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertRoom(RoomModel room) async {
    final db = await database;
    await db.insert(
      'rooms',
      room.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRoomLocal(String id) async {
    final db = await database;
    await db.delete('rooms', where: 'room_id = ?', whereArgs: [id]);
  }

  Future<List<RoomModel>> getRooms() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('rooms');
    return List.generate(maps.length, (i) => RoomModel.fromJson(maps[i]));
  }

  // --- Tenants ---
  Future<void> saveTenants(List<TenantModel> tenants) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tenants');
      for (var tenant in tenants) {
        await txn.insert(
          'tenants',
          tenant.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertTenant(TenantModel tenant) async {
    final db = await database;
    await db.insert(
      'tenants',
      tenant.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTenantLocal(String id) async {
    final db = await database;
    await db.delete('tenants', where: 'tenant_id = ?', whereArgs: [id]);
  }

  Future<List<TenantModel>> getTenants() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tenants');
    return List.generate(maps.length, (i) => TenantModel.fromJson(maps[i]));
  }

  // --- Payments ---
  Future<void> savePayments(List<PaymentModel> payments) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('payments');
      for (var payment in payments) {
        await txn.insert(
          'payments',
          payment.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertPayment(PaymentModel payment) async {
    final db = await database;
    await db.insert(
      'payments',
      payment.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePaymentLocal(String id) async {
    final db = await database;
    await db.delete('payments', where: 'payment_id = ?', whereArgs: [id]);
  }

  Future<List<PaymentModel>> getPayments() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('payments');
    return List.generate(maps.length, (i) => PaymentModel.fromJson(maps[i]));
  }

  // --- Beds ---
  Future<void> saveBeds(List<BedModel> beds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('beds');
      for (var bed in beds) {
        await txn.insert(
          'beds',
          bed.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertBed(BedModel bed) async {
    final db = await database;
    await db.insert(
      'beds',
      bed.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BedModel>> getBeds() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('beds');
    return List.generate(maps.length, (i) => BedModel.fromJson(maps[i]));
  }

  Future<void> deleteBedLocal(String id) async {
    final db = await database;
    await db.delete('beds', where: 'bed_id = ?', whereArgs: [id]);
  }

  // --- Expenses ---
  Future<void> saveExpenses(List<ExpenseModel> expenses) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('expenses');
      for (var expense in expenses) {
        await txn.insert(
          'expenses',
          expense.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<ExpenseModel>> getExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('expenses');
    return List.generate(maps.length, (i) => ExpenseModel.fromJson(maps[i]));
  }

  Future<void> upsertExpense(ExpenseModel expense) async {
    final db = await database;
    await db.insert(
      'expenses',
      expense.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteExpenseLocal(String id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  int revision = 0;

  Future<void> _createBookings(Database db) => db.execute('''
    CREATE TABLE bookings(
      booking_id TEXT PRIMARY KEY, tenant_name TEXT, phone TEXT,
      building_id TEXT, room_id TEXT, bed_id TEXT, move_in_date TEXT,
      rent_amount REAL, advance_amount REAL, rent_paid REAL,
      payment_date TEXT, rent_due_day INTEGER, status TEXT, refund_amount REAL
    )
  ''');

  Future<List<BookingModel>> getBookings() async {
    final rows =
        await (await database).query('bookings', orderBy: 'move_in_date ASC');
    return rows.map(BookingModel.fromJson).toList();
  }

  Future<void> _queueBooking(
      Transaction txn, String type, Map<String, dynamic> payload) async {
    await txn.insert('mutation_queue', {
      'id': const Uuid().v4(),
      'type': type,
      'payload': jsonEncode(payload),
      'timestamp': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }

  Future<void> createBooking(BookingModel booking) async {
    booking.validate();
    if (booking.status != BookingStatus.reserved ||
        booking.refundAmount != 0 ||
        BookingModel.day(booking.paymentDate)
            .isAfter(BookingModel.day(DateTime.now()))) {
      throw StateError('Create a reserved booking with a valid payment date.');
    }
    if (BookingModel.day(booking.moveInDate)
        .isBefore(BookingModel.day(DateTime.now()))) {
      throw StateError('Choose today or a future move-in date.');
    }
    final db = await database;
    await db.transaction((txn) async {
      final rooms = (await txn.query('rooms')).map(RoomModel.fromJson).toList();
      final room =
          rooms.where((room) => room.roomId == booking.roomId).firstOrNull;
      final beds = await txn
          .query('beds', where: 'bed_id = ?', whereArgs: [booking.bedId]);
      final reservations = await txn.query('bookings',
          where: 'bed_id = ? AND status = ?',
          whereArgs: [booking.bedId, 'reserved']);
      final occupants = (await txn.query('tenants',
              where: 'bed_id = ? AND active = ?',
              whereArgs: [booking.bedId, 'TRUE']))
          .map(TenantModel.fromJson)
          .toList();
      if (room == null ||
          !room.isAvailable(rooms) ||
          room.buildingId != booking.buildingId ||
          beds.isEmpty ||
          beds.first['room_id'] != booking.roomId ||
          reservations.isNotEmpty) {
        throw StateError(
            'Choose an available bed without an existing booking.');
      }
      if (occupants.any((tenant) =>
              tenant.checkoutDate == null ||
              BookingModel.day(tenant.checkoutDate!)
                  .isAfter(BookingModel.day(booking.moveInDate))) ||
          (occupants.isEmpty && beds.first['status'] == 'OCCUPIED')) {
        throw StateError(
            'Schedule the current tenant’s checkout before the move-in date.');
      }
      await txn.insert('bookings', booking.toJson());
      final payment = booking.rentPayment;
      if (payment != null) await txn.insert('payments', payment.toJson());
      await _queueBooking(txn, 'ADD_BOOKING', booking.toJson());
      revision++;
    });
  }

  Future<BookingModel> _reservedBooking(Transaction txn, String id) async {
    final rows =
        await txn.query('bookings', where: 'booking_id = ?', whereArgs: [id]);
    if (rows.isEmpty || rows.first['status'] != 'reserved') {
      throw StateError('This booking has already been processed.');
    }
    return BookingModel.fromJson(rows.first);
  }

  Future<void> checkInBooking(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      final booking = await _reservedBooking(txn, id);
      if (BookingModel.day(booking.moveInDate)
          .isAfter(BookingModel.day(DateTime.now()))) {
        throw StateError('Check-in is available on the booked move-in date.');
      }
      final beds = await txn
          .query('beds', where: 'bed_id = ?', whereArgs: [booking.bedId]);
      final occupants = await txn.query('tenants',
          where: 'bed_id = ? AND active = ?',
          whereArgs: [booking.bedId, 'TRUE']);
      final rooms = (await txn.query('rooms')).map(RoomModel.fromJson).toList();
      final room =
          rooms.where((room) => room.roomId == booking.roomId).firstOrNull;
      if (room == null ||
          !room.isAvailable(rooms) ||
          beds.isEmpty ||
          beds.first['status'] != 'VACANT' ||
          occupants.isNotEmpty) {
        throw StateError(
            'Confirm the previous tenant’s checkout before checking in.');
      }
      final updated = booking.withStatus(BookingStatus.checkedIn);
      await txn.insert('tenants', booking.toTenant().toJson());
      await txn.update('bookings', updated.toJson(),
          where: 'booking_id = ?', whereArgs: [id]);
      await txn.update('beds', {'status': 'OCCUPIED'},
          where: 'bed_id = ?', whereArgs: [booking.bedId]);
      await _queueBooking(txn, 'CHECK_IN_BOOKING', updated.toJson());
      revision++;
    });
  }

  Future<void> cancelBooking(String id, double refund) async {
    final db = await database;
    await db.transaction((txn) async {
      final booking = await _reservedBooking(txn, id);
      final updated =
          booking.withStatus(BookingStatus.cancelled, refund: refund);
      updated.validate();
      await txn.update('bookings', updated.toJson(),
          where: 'booking_id = ?', whereArgs: [id]);
      final expense = refund > 0
          ? ExpenseModel(
              id: 'booking_refund_$id',
              roomId: booking.roomId,
              tenantId: id,
              expenseType: ExpenseType.refund,
              amount: refund,
              date: BookingModel.day(DateTime.now()),
              description: 'Booking refund to ${booking.tenantName}')
          : null;
      if (expense != null) await txn.insert('expenses', expense.toJson());
      await _queueBooking(txn, 'CANCEL_BOOKING', {
        'booking': updated.toJson(),
        'expense': expense?.toJson(),
      });
      revision++;
    });
  }

  /// Commit local changes and their retry record together.
  Future<void> commitMutation(Map<String, dynamic> mutation) async {
    final db = await database;
    final payload =
        jsonDecode(mutation['payload'] as String) as Map<String, dynamic>;
    final type = mutation['type'] as String;
    const tables = {
      'BUILDING': ('buildings', 'building_id'),
      'ROOM': ('rooms', 'room_id'),
      'TENANT': ('tenants', 'tenant_id'),
      'PAYMENT': ('payments', 'payment_id'),
      'BED': ('beds', 'bed_id'),
      'EXPENSE': ('expenses', 'id'),
    };
    await db.transaction((txn) async {
      final previous = type.endsWith('_TENANT')
          ? await txn.query('tenants',
              where: 'tenant_id = ?',
              whereArgs: [payload['tenant_id'] ?? payload['id']])
          : <Map<String, Object?>>[];
      if (type.endsWith('_TENANT') && payload['active'] == 'TRUE') {
        final reservations = (await txn.query('bookings',
                where: 'bed_id = ? AND status = ? AND booking_id != ?',
                whereArgs: [
              payload['bed_id'],
              'reserved',
              payload['tenant_id']
            ]))
            .map(BookingModel.fromJson);
        final checkout = DateTime.tryParse('${payload['checkout_date']}');
        if (reservations.any((booking) =>
            checkout == null ||
            BookingModel.day(checkout)
                .isAfter(BookingModel.day(booking.moveInDate)))) {
          throw StateError(
              'This bed has a booking. Checkout must be on or before its move-in date.');
        }
        final conflicts = await txn.query('tenants',
            where: 'bed_id = ? AND active = ? AND tenant_id != ?',
            whereArgs: [payload['bed_id'], 'TRUE', payload['tenant_id']]);
        final beds = await txn
            .query('beds', where: 'bed_id = ?', whereArgs: [payload['bed_id']]);
        if (conflicts.isNotEmpty ||
            beds.isEmpty ||
            beds.first['room_id'] != payload['room_id']) {
          throw StateError('Choose a vacant bed in the selected room.');
        }
      }
      if (type == 'UPDATE_BED_STATUS') {
        await txn.update(
            'beds',
            {
              'status': payload['status'] == 'BedStatus.occupied'
                  ? 'OCCUPIED'
                  : 'VACANT',
            },
            where: 'bed_id = ?',
            whereArgs: [payload['bedId']]);
      } else {
        final entity = type.substring(type.indexOf('_') + 1);
        final (table, key) = tables[entity]!;
        if (type.startsWith('DELETE_')) {
          if (['BED', 'ROOM', 'BUILDING'].contains(entity)) {
            final bookingKey = {
              'BED': 'bed_id',
              'ROOM': 'room_id',
              'BUILDING': 'building_id'
            }[entity]!;
            final reservations = await txn.query('bookings',
                where: '$bookingKey = ? AND status = ?',
                whereArgs: [payload['id'], 'reserved']);
            if (reservations.isNotEmpty) {
              throw StateError(
                  'Cancel the bookings before deleting this space.');
            }
          }
          await txn
              .delete(table, where: '$key = ?', whereArgs: [payload['id']]);
        } else {
          await txn.insert(table, payload,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await txn.insert('mutation_queue', mutation);
      if (type.endsWith('_TENANT')) {
        final affected = <String>{
          if (previous.isNotEmpty) previous.first['bed_id'] as String,
          if (payload['bed_id'] != null) payload['bed_id'] as String,
        };
        for (final bedId in affected) {
          final occupants = await txn.query('tenants',
              where: 'bed_id = ? AND active = ?', whereArgs: [bedId, 'TRUE']);
          await _saveBedStatus(txn, bedId,
              occupants.isEmpty ? BedStatus.vacant : BedStatus.occupied);
        }
      }
      revision++;
    });
  }

  Future<void> _saveBedStatus(
      Transaction txn, String bedId, BedStatus status) async {
    final changed = await txn.update('beds',
        {'status': status == BedStatus.occupied ? 'OCCUPIED' : 'VACANT'},
        where: 'bed_id = ?', whereArgs: [bedId]);
    if (changed == 0) return;
    await txn.insert('mutation_queue', {
      'id': const Uuid().v4(),
      'type': 'UPDATE_BED_STATUS',
      'payload': jsonEncode({'bedId': bedId, 'status': status.toString()}),
      'timestamp': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }

  /// Reject a stale remote snapshot when local writes intervened.
  Future<void> saveSnapshot(List<dynamic> results,
      {required int expectedRevision}) async {
    final db = await database;
    await db.transaction((txn) async {
      final pending = await txn.query('mutation_queue', limit: 1);
      if (revision != expectedRevision || pending.isNotEmpty) return;
      final tables = [
        'buildings',
        'rooms',
        'tenants',
        'payments',
        'beds',
        'expenses',
        if (results.length > 6) 'bookings',
      ];
      for (var i = 0; i < tables.length; i++) {
        await txn.delete(tables[i]);
        for (final model in results[i] as List) {
          await txn.insert(tables[i], model.toJson() as Map<String, dynamic>,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      final occupied = (results[2] as List<TenantModel>)
          .where((tenant) => tenant.active)
          .map((tenant) => tenant.bedId)
          .toSet();
      for (final bed in results[4] as List<BedModel>) {
        if (bed.bedId != null &&
            occupied.contains(bed.bedId) &&
            bed.status != BedStatus.occupied) {
          await _saveBedStatus(txn, bed.bedId!, BedStatus.occupied);
        }
      }
    });
  }

  // --- Mutation Queue ---
  Future<List<Map<String, dynamic>>> getMutationQueue() async {
    final db = await database;
    return await db.query('mutation_queue', orderBy: 'rowid ASC');
  }

  Future<void> addToQueue(Map<String, dynamic> mutation) async {
    final db = await database;
    await db.insert(
      'mutation_queue',
      mutation,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFromQueue(String id) async {
    final db = await database;
    await db.delete('mutation_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateMutationRetryCount(String id, int count) async {
    final db = await database;
    await db.update(
      'mutation_queue',
      {'retry_count': count},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('buildings');
      await txn.delete('rooms');
      await txn.delete('tenants');
      await txn.delete('payments');
      await txn.delete('beds');
      await txn.delete('expenses');
      await txn.delete('bookings');
      await txn.delete('mutation_queue');
    });
  }
}
