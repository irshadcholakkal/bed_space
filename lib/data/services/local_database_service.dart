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
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
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

  // --- Mutation Queue ---
  Future<List<Map<String, dynamic>>> getMutationQueue() async {
    final db = await database;
    return await db.query('mutation_queue', orderBy: 'timestamp ASC');
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
      await txn.delete('mutation_queue');
    });
  }
}
