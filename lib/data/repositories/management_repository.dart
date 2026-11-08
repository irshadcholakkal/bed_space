import 'dart:async';
import '../services/google_sheets_service.dart';
import '../services/local_database_service.dart';
import '../models/building_model.dart';
import '../models/room_model.dart';
import '../models/tenant_model.dart';
import '../models/payment_model.dart';
import '../models/bed_model.dart';
import '../models/expense_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'sync_worker.dart';

class ManagementRepository {
  final GoogleSheetsService _sheetsService;
  final LocalDatabaseService _localService;

  final _dataChangeController = StreamController<void>.broadcast();
  StreamSubscription? _connectivitySubscription;

  ManagementRepository({
    required GoogleSheetsService sheetsService,
    LocalDatabaseService? localService,
  })  : _sheetsService = sheetsService,
        _localService = localService ?? LocalDatabaseService() {
    _initConnectivityListener();
    _processQueue(); // Process any pending mutations on startup
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none,
      );
      if (hasConnection) {
        _processQueue();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _dataChangeController.close();
  }

  // --- Real-time Data Stream ---

  Stream<Map<String, dynamic>> getAllDataStream() async* {
    // 1. Initial emission of current local data immediately
    Map<String, dynamic> initialData = await _getLocalData();
    initialData['source'] = 'local_initial';
    yield initialData;

    // 2. Start background sync from sheets WITHOUT blocking the stream
    // This will eventually trigger _dataChangeController
    unawaited(_syncSheetsToLocal());

    // 3. Yield updated data whenever local database changes
    yield* _dataChangeController.stream.asyncMap((_) async {
      final data = await _getLocalData();
      data['source'] = 'local_update';
      return data;
    });
  }

  Future<Map<String, dynamic>> _getLocalData() async {
    final results = await Future.wait([
      _localService.getBuildings(),
      _localService.getRooms(),
      _localService.getTenants(),
      _localService.getPayments(),
      _localService.getBeds(),
      _localService.getExpenses(),
    ]);

    return {
      'buildings': results[0] as List<BuildingModel>,
      'rooms': results[1] as List<RoomModel>,
      'tenants': results[2] as List<TenantModel>,
      'payments': results[3] as List<PaymentModel>,
      'beds': results[4] as List<BedModel>,
      'expenses': results[5] as List<ExpenseModel>,
    };
  }

  Future<void> _syncSheetsToLocal() async {
    try {
      final results = await Future.wait([
        _sheetsService.getBuildings(),
        _sheetsService.getRooms(),
        _sheetsService.getTenants(),
        _sheetsService.getPayments(),
        _sheetsService.getBeds(),
        _sheetsService.getExpenses(),
      ]);

      await _localService.saveBuildings(results[0] as List<BuildingModel>);
      await _localService.saveRooms(results[1] as List<RoomModel>);
      await _localService.saveTenants(results[2] as List<TenantModel>);
      await _localService.savePayments(results[3] as List<PaymentModel>);
      await _localService.saveBeds(results[4] as List<BedModel>);
      await _localService.saveExpenses(results[5] as List<ExpenseModel>);

      _dataChangeController.add(null);
    } catch (e) {
      // Background Sync Error ignored for now
    }
  }

  void notifyDataChanged() {
    _dataChangeController.add(null);
  }

  Future<void> triggerSync() async {
    await _processQueue();
    await syncWithSheets();
  }

  Future<void> syncWithSheets() async {
    await _syncSheetsToLocal();
  }

  // --- Mutation Queue Worker ---

  Future<void> _enqueue(String type, dynamic model) async {
    final mutation = {
      'id': const Uuid().v4(),
      'type': type,
      'payload': jsonEncode(model is Map ? model : model.toJson()),
      'timestamp': DateTime.now().toIso8601String(),
      'retry_count': 0,
    };
    await _localService.addToQueue(mutation);
    _processQueue(); // Try processing immediately if online
  }

  Future<void> _processQueue() async {
    final success = await SyncWorker().processQueue();
    if (success) {
      notifyDataChanged();
    }
  }

  // _processMutation is now in SyncWorker

  // --- Mutation Helpers (OFFLINE FIRST) ---

  Future<void> addBuilding(BuildingModel building) async {
    final buildingWithId =
        building.buildingId == null || building.buildingId!.isEmpty
            ? building.copyWith(buildingId: const Uuid().v4())
            : building;

    await _localService.upsertBuilding(buildingWithId);
    _dataChangeController.add(null);

    // Fire-and-forget sync
    unawaited(_syncAddBuilding(buildingWithId));
  }

  Future<void> _syncAddBuilding(BuildingModel building) async {
    try {
      await _sheetsService.addBuilding(building);
      await _syncSheetsToLocal();
    } catch (e) {
      await _enqueue('ADD_BUILDING', building);
    }
  }

  Future<void> updateBuilding(BuildingModel building) async {
    await _localService.upsertBuilding(building);
    _dataChangeController.add(null);

    unawaited(_syncUpdateBuilding(building));
  }

  Future<void> _syncUpdateBuilding(BuildingModel building) async {
    try {
      await _sheetsService.updateBuilding(building);
    } catch (e) {
      await _enqueue('UPDATE_BUILDING', building);
    }
  }

  Future<void> deleteBuilding(String id) async {
    await _localService.deleteBuildingLocal(id);
    _dataChangeController.add(null);

    unawaited(_syncDeleteBuilding(id));
  }

  Future<void> _syncDeleteBuilding(String id) async {
    try {
      await _sheetsService.deleteBuilding(id);
    } catch (e) {
      await _enqueue('DELETE_BUILDING', {'id': id});
    }
  }

  Future<RoomModel> addRoom(RoomModel room) async {
    room.validateHierarchy(await _localService.getRooms());
    final roomWithId = room.roomId == null || room.roomId!.isEmpty
        ? RoomModel(
            roomId: const Uuid().v4(),
            buildingId: room.buildingId,
            roomNumber: room.roomNumber,
            parentRoomId: room.parentRoomId,
            totalCapacity: room.totalCapacity,
            lowerBedsCount: room.lowerBedsCount,
            upperBedsCount: room.upperBedsCount,
            lowerBedRent: room.lowerBedRent,
            upperBedRent: room.upperBedRent,
            utilityCostMonthly: room.utilityCostMonthly,
            monthlyRent: room.monthlyRent,
          )
        : room;

    await _localService.upsertRoom(roomWithId);
    _dataChangeController.add(null);

    unawaited(_syncAddRoom(roomWithId));
    return roomWithId;
  }

  Future<void> _syncAddRoom(RoomModel room) async {
    try {
      await _sheetsService.addRoom(room);
      await _syncSheetsToLocal();
    } catch (e) {
      await _enqueue('ADD_ROOM', room);
    }
  }

  Future<void> updateRoom(RoomModel room) async {
    room.validateHierarchy(await _localService.getRooms());
    await _localService.upsertRoom(room);
    _dataChangeController.add(null);

    unawaited(_syncUpdateRoom(room));
  }

  Future<void> _syncUpdateRoom(RoomModel room) async {
    try {
      await _sheetsService.updateRoom(room);
    } catch (e) {
      await _enqueue('UPDATE_ROOM', room);
    }
  }

  Future<void> deleteRoom(String id) async {
    final rooms = await _localService.getRooms();
    if (rooms.any((room) => room.parentRoomId == id)) {
      throw StateError('Remove the subrooms before deleting this room.');
    }
    await _localService.deleteRoomLocal(id);
    _dataChangeController.add(null);

    unawaited(_syncDeleteRoom(id));
  }

  Future<void> _syncDeleteRoom(String id) async {
    try {
      await _sheetsService.deleteRoom(id);
    } catch (e) {
      await _enqueue('DELETE_ROOM', {'id': id});
    }
  }

  Future<void> addTenant(TenantModel tenant) async {
    final tenantWithId = tenant.tenantId == null || tenant.tenantId!.isEmpty
        ? tenant.copyWith(tenantId: const Uuid().v4())
        : tenant;

    await _localService.upsertTenant(tenantWithId);
    _dataChangeController.add(null);

    unawaited(_syncAddTenant(tenantWithId));
  }

  Future<void> _syncAddTenant(TenantModel tenant) async {
    try {
      await _sheetsService.addTenant(tenant);
      await _syncSheetsToLocal();
    } catch (e) {
      await _enqueue('ADD_TENANT', tenant);
    }
  }

  Future<void> updateTenant(TenantModel tenant) async {
    await _localService.upsertTenant(tenant);
    _dataChangeController.add(null);

    unawaited(_syncUpdateTenant(tenant));
  }

  Future<void> _syncUpdateTenant(TenantModel tenant) async {
    try {
      await _sheetsService.updateTenant(tenant);
    } catch (e) {
      await _enqueue('UPDATE_TENANT', tenant);
    }
  }

  Future<void> deleteTenant(String id) async {
    await _localService.deleteTenantLocal(id);
    _dataChangeController.add(null);

    unawaited(_syncDeleteTenant(id));
  }

  Future<void> _syncDeleteTenant(String id) async {
    try {
      await _sheetsService.deleteTenant(id);
    } catch (e) {
      await _enqueue('DELETE_TENANT', {'id': id});
    }
  }

  Future<void> addPayment(PaymentModel payment) async {
    final paymentWithId =
        payment.paymentId == null || payment.paymentId!.isEmpty
            ? PaymentModel(
                paymentId: const Uuid().v4(),
                tenantId: payment.tenantId,
                amount: payment.amount,
                paymentMonth: payment.paymentMonth,
                paidDate: payment.paidDate,
              )
            : payment;

    await _localService.upsertPayment(paymentWithId);
    _dataChangeController.add(null);

    // Background sync: Do not await this.
    // If it fails, we handle it in the background or queue it.
    unawaited(_syncPaymentToSheets(paymentWithId));
  }

  Future<void> _syncPaymentToSheets(PaymentModel payment) async {
    try {
      await _sheetsService.addPayment(payment);
    } catch (e) {
      await _enqueue('ADD_PAYMENT', payment);
    }
  }

  Future<void> deletePayment(String paymentId) async {
    await _localService.deletePaymentLocal(paymentId);
    _dataChangeController.add(null);

    unawaited(_syncDeletePayment(paymentId));
  }

  Future<void> _syncDeletePayment(String paymentId) async {
    try {
      await _sheetsService.deletePayment(paymentId);
    } catch (e) {
      await _enqueue('DELETE_PAYMENT', {'id': paymentId});
    }
  }

  Future<void> updateBedStatus(String bedId, BedStatus status) async {
    final beds = await _localService.getBeds();
    final index = beds.indexWhere((b) => b.bedId == bedId);
    if (index != -1) {
      final updatedBed = BedModel(
        bedId: beds[index].bedId,
        roomId: beds[index].roomId,
        bedType: beds[index].bedType,
        status: status,
      );
      await _localService.upsertBed(updatedBed);
      _dataChangeController.add(null);
    }

    unawaited(_syncUpdateBedStatus(bedId, status));
  }

  Future<void> _syncUpdateBedStatus(String bedId, BedStatus status) async {
    try {
      await _sheetsService.updateBedStatus(bedId, status);
    } catch (e) {
      await _enqueue('UPDATE_BED_STATUS', {
        'bedId': bedId,
        'status': status.toString(),
      });
    }
  }

  // --- Expenses ---

  Future<void> addExpense(ExpenseModel expense) async {
    final expenseWithId = expense.id == null || expense.id!.isEmpty
        ? expense.copyWith(id: const Uuid().v4())
        : expense;

    await _localService.upsertExpense(expenseWithId);
    _dataChangeController.add(null);

    unawaited(_syncAddExpense(expenseWithId));
  }

  Future<void> _syncAddExpense(ExpenseModel expense) async {
    try {
      await _sheetsService.addExpense(expense);
    } catch (e) {
      await _enqueue('ADD_EXPENSE', expense);
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    await _localService.deleteExpenseLocal(expenseId);
    _dataChangeController.add(null);

    unawaited(_syncDeleteExpense(expenseId));
  }

  Future<void> _syncDeleteExpense(String expenseId) async {
    try {
      await _sheetsService.deleteExpense(expenseId);
    } catch (e) {
      await _enqueue('DELETE_EXPENSE', {'id': expenseId});
    }
  }

  Future<List<ExpenseModel>> getExpenses({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final local = await _localService.getExpenses();
      if (local.isNotEmpty) return local;
    }
    final fresh = await _sheetsService.getExpenses();
    await _localService.saveExpenses(fresh);
    return fresh;
  }

  // --- Getters (Local-First) ---

  Future<List<BuildingModel>> getBuildings({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final local = await _localService.getBuildings();
      if (local.isNotEmpty) return local;
    }
    final fresh = await _sheetsService.getBuildings();
    await _localService.saveBuildings(fresh);
    return fresh;
  }

  Future<List<RoomModel>> getRooms({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final local = await _localService.getRooms();
      if (local.isNotEmpty) return local;
    }
    final fresh = await _sheetsService.getRooms();
    await _localService.saveRooms(fresh);
    return fresh;
  }

  Future<List<TenantModel>> getTenants({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final local = await _localService.getTenants();
      if (local.isNotEmpty) return local;
    }
    final fresh = await _sheetsService.getTenants();
    await _localService.saveTenants(fresh);
    return fresh;
  }

  Future<List<PaymentModel>> getPayments({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final local = await _localService.getPayments();
      if (local.isNotEmpty) return local;
    }
    final fresh = await _sheetsService.getPayments();
    await _localService.savePayments(fresh);
    return fresh;
  }

  Future<void> addBed(BedModel bed) async {
    final bedWithId = bed.bedId == null || bed.bedId!.isEmpty
        ? BedModel(
            bedId: const Uuid().v4(),
            roomId: bed.roomId,
            bedType: bed.bedType,
            status: bed.status,
          )
        : bed;

    await _localService.upsertBed(bedWithId);
    _dataChangeController.add(null);

    unawaited(_syncAddBed(bedWithId));
  }

  Future<void> _syncAddBed(BedModel bed) async {
    try {
      await _sheetsService.addBed(bed);
    } catch (e) {
      await _enqueue('ADD_BED', bed);
    }
  }

  Future<void> deleteBed(String bedId) async {
    await _localService.deleteBedLocal(bedId);
    _dataChangeController.add(null);

    unawaited(_syncDeleteBed(bedId));
  }

  Future<void> _syncDeleteBed(String bedId) async {
    try {
      await _sheetsService.deleteBed(bedId);
    } catch (e) {
      await _enqueue('DELETE_BED', {'id': bedId});
    }
  }

  Future<TenantModel?> getTenantById(String tenantId) async {
    final local = await _localService.getTenants();
    try {
      return local.firstWhere((t) => t.tenantId == tenantId);
    } catch (e) {
      return await _sheetsService.getTenantById(tenantId);
    }
  }

  Future<Map<String, dynamic>> getTenantRentBalance(String tenantId) async {
    final tenant = await getTenantById(tenantId);
    if (tenant == null) {
      return {
        'totalDue': 0.0,
        'totalPaid': 0.0,
        'balance': 0.0,
        'payments': [],
      };
    }

    final allPayments = await _localService.getPayments();
    final payments = allPayments.where((p) => p.tenantId == tenantId).toList();

    // Fetch tenant-specific expenses (e.g., refunds)
    final allExpenses = await _localService.getExpenses();
    final tenantExpenses =
        allExpenses.where((e) => e.tenantId == tenantId).toList();

    final now = DateTime.now();
    final joiningDate = DateTime(
      tenant.joiningDate.year,
      tenant.joiningDate.month,
      tenant.joiningDate.day,
    );

    double totalDue = 0.0;
    int totalDays = 0;

    if (!tenant.active && tenant.checkoutDate != null) {
      // For inactive tenants, use the actual duration of stay
      final chDate = DateTime(
        tenant.checkoutDate!.year,
        tenant.checkoutDate!.month,
        tenant.checkoutDate!.day,
      );
      final duration = chDate.difference(joiningDate).inDays + 1;
      totalDays = duration > 0 ? duration : 0;
      totalDue = (tenant.rentAmount / 30) * totalDays;
    } else {
      // For active tenants, calculate up to current month (legacy behavior or current month prorated?)
      // Keeping legacy month-based calculation for active tenants for now to maintain consistency,
      // but normalizing to midnight.
      final startMonth = DateTime(joiningDate.year, joiningDate.month);
      final currentMonth = DateTime(now.year, now.month);

      int monthsCount = 0;
      DateTime month = startMonth;
      while (month.isBefore(currentMonth) ||
          month.isAtSameMomentAs(currentMonth)) {
        monthsCount++;
        month = DateTime(month.year, month.month + 1);
      }
      totalDue = tenant.rentAmount * monthsCount;
    }

    final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
    final totalRefunded =
        tenantExpenses.fold<double>(0, (sum, e) => sum + e.amount);

    // Balance = (What they should pay) - (What they actually paid net)
    // Net Paid = Total Paid - Total Refunded
    final balance = totalDue - (totalPaid - totalRefunded);

    return {
      'totalDue': totalDue,
      'totalPaid': totalPaid,
      'totalRefunded': totalRefunded,
      'balance': balance,
      'payments': payments,
      'expenses': tenantExpenses,
      'tenant': tenant,
      'stayDays': totalDays,
    };
  }

  Future<void> checkoutTenant({
    required TenantModel tenant,
    required DateTime checkoutDate,
    double? refundAmount,
  }) async {
    // 1. Update tenant status and checkout date
    final updatedTenant = tenant.copyWith(
      active: false,
      checkoutDate: checkoutDate,
    );
    await updateTenant(updatedTenant);

    // 2. Update bed status
    await updateBedStatus(tenant.bedId, BedStatus.vacant);

    // 3. Create refund expense if applicable
    if (refundAmount != null && refundAmount > 0) {
      final refundExpense = ExpenseModel(
        roomId: tenant.roomId,
        tenantId: tenant.tenantId,
        expenseType: ExpenseType.refund,
        amount: refundAmount,
        date: checkoutDate,
        description: 'Refund to ${tenant.tenantName} on checkout',
      );
      await addExpense(refundExpense);
    }
  }

  Future<List<BedModel>> getBeds({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final localBeds = await _localService.getBeds();
      if (localBeds.isNotEmpty) return localBeds;
    }

    final beds = await _sheetsService.getBeds();
    await _localService.saveBeds(beds);
    return beds;
  }
}
