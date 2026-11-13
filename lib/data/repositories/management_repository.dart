import '../models/booking_model.dart';
import 'dart:developer' as developer;
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
  Timer? _syncTimer;
  Future<void>? _refresh;

  ManagementRepository({
    required GoogleSheetsService sheetsService,
    LocalDatabaseService? localService,
  })  : _sheetsService = sheetsService,
        _localService = localService ?? LocalDatabaseService() {
    _initConnectivityListener();
    unawaited(syncWithSheets());
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(syncWithSheets());
    });
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none,
      );
      if (hasConnection) {
        unawaited(syncWithSheets());
      }
    });
  }

  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _dataChangeController.close();
  }

  // --- Real-time Data Stream ---

  Stream<Map<String, dynamic>> getAllDataStream() {
    late StreamController<Map<String, dynamic>> controller;
    StreamSubscription<void>? subscription;
    Future<void> reads = Future.value();
    void publish(String source) {
      reads = reads.then((_) async {
        final data = await _getLocalData();
        data['source'] = source;
        if (!controller.isClosed) controller.add(data);
      }).catchError((Object error, StackTrace stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      });
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        subscription = _dataChangeController.stream
            .listen((_) => publish('local_update'), onDone: controller.close);
        publish('local_initial');
        unawaited(syncWithSheets());
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  Future<Map<String, dynamic>> _getLocalData() async {
    final results = await Future.wait([
      _localService.getBuildings(),
      _localService.getRooms(),
      _localService.getTenants(),
      _localService.getPayments(),
      _localService.getBeds(),
      _localService.getExpenses(),
      _localService.getBookings(),
    ]);

    return {
      'buildings': results[0] as List<BuildingModel>,
      'rooms': results[1] as List<RoomModel>,
      'tenants': results[2] as List<TenantModel>,
      'payments': results[3] as List<PaymentModel>,
      'beds': (results[4] as List<BedModel>)
          .where((bed) => (results[1] as List<RoomModel>)
              .any((room) => room.roomId == bed.roomId))
          .toList(),
      'expenses': results[5] as List<ExpenseModel>,
      'bookings': results[6] as List<BookingModel>,
    };
  }

  Future<void> _syncSheetsToLocal() {
    return _refresh ??=
        _refreshFromSheets().whenComplete(() => _refresh = null);
  }

  Future<void> _refreshFromSheets() async {
    final revision = _localService.revision;
    if ((await _localService.getMutationQueue()).isNotEmpty) return;
    final results = await Future.wait([
      _sheetsService.getBuildings(),
      _sheetsService.getRooms(),
      _sheetsService.getTenants(),
      _sheetsService.getPayments(),
      _sheetsService.getBeds(),
      _sheetsService.getExpenses(),
      _sheetsService.getBookings(),
    ]);

    final roomIds =
        (results[1] as List<RoomModel>).map((room) => room.roomId).toSet();
    results[4] = (results[4] as List<BedModel>)
        .where((bed) => roomIds.contains(bed.roomId))
        .toList();
    await _localService.saveSnapshot(results, expectedRevision: revision);

    notifyDataChanged();
    if (!await _processQueue()) {
      throw StateError(
          'Google sync is pending. Changes are saved locally and will retry.');
    }
  }

  void notifyDataChanged() {
    if (!_dataChangeController.isClosed) _dataChangeController.add(null);
  }

  Future<void> triggerSync() async {
    if (!await _processQueue()) {
      throw StateError(
          'Google sync is pending. Changes are saved locally and will retry.');
    }
    await _syncSheetsToLocal();
  }

  Future<void> syncWithSheets() async {
    try {
      await triggerSync();
    } catch (error, stack) {
      developer.log('Google sync deferred', error: error, stackTrace: stack);
    }
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
    await _localService.commitMutation(mutation);
    _processQueue(); // Try processing immediately if online
  }

  Future<bool> _processQueue() async {
    final success = await SyncWorker().processQueue(
        sheetsService: _sheetsService, localService: _localService);
    if (success) {
      notifyDataChanged();
    }
    return success;
  }

  // _processMutation is now in SyncWorker

  // --- Mutation Helpers (OFFLINE FIRST) ---

  Future<void> addBuilding(BuildingModel building) async {
    final buildingWithId =
        building.buildingId == null || building.buildingId!.isEmpty
            ? building.copyWith(buildingId: const Uuid().v4())
            : building;

    await _enqueue('ADD_BUILDING', buildingWithId);
    notifyDataChanged();
  }

  Future<void> updateBuilding(BuildingModel building) async {
    await _enqueue('UPDATE_BUILDING', building);
    notifyDataChanged();
  }

  Future<void> deleteBuilding(String id) async {
    await _enqueue('DELETE_BUILDING', {'id': id});
    notifyDataChanged();
  }

  Future<RoomModel> addRoom(RoomModel room) async {
    room.validateHierarchy(await _localService.getRooms());
    final roomWithId = room.roomId == null || room.roomId!.isEmpty
        ? RoomModel(
            available: room.available,
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

    await _enqueue('ADD_ROOM', roomWithId);
    notifyDataChanged();

    return roomWithId;
  }

  Future<void> updateRoom(RoomModel room) async {
    room.validateHierarchy(await _localService.getRooms());
    await _enqueue('UPDATE_ROOM', room);
    notifyDataChanged();
  }

  Future<void> deleteRoom(String id) async {
    final rooms = await _localService.getRooms();
    if (rooms.any((room) => room.parentRoomId == id)) {
      throw StateError('Remove the subrooms before deleting this room.');
    }
    await _enqueue('DELETE_ROOM', {'id': id});
    notifyDataChanged();
  }

  Future<void> addBooking(BookingModel booking) async {
    await _localService.createBooking(booking);
    notifyDataChanged();
    unawaited(_processQueue());
  }

  Future<List<BookingModel>> getBookings() => _localService.getBookings();

  Future<void> checkInBooking(String id) async {
    await _localService.checkInBooking(id);
    notifyDataChanged();
    unawaited(_processQueue());
  }

  Future<void> cancelBooking(String id, {double refund = 0}) async {
    await _localService.cancelBooking(id, refund);
    notifyDataChanged();
    unawaited(_processQueue());
  }

  Future<void> addTenant(TenantModel tenant) async {
    final tenantWithId = tenant.tenantId == null || tenant.tenantId!.isEmpty
        ? tenant.copyWith(tenantId: const Uuid().v4())
        : tenant;

    await _enqueue('ADD_TENANT', tenantWithId);
    notifyDataChanged();
  }

  Future<void> updateTenant(TenantModel tenant) async {
    await _enqueue('UPDATE_TENANT', tenant);
    notifyDataChanged();
  }

  Future<void> deleteTenant(String id) async {
    await _enqueue('DELETE_TENANT', {'id': id});
    notifyDataChanged();
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

    await _enqueue('ADD_PAYMENT', paymentWithId);
    notifyDataChanged();
  }

  Future<void> deletePayment(String paymentId) async {
    await _enqueue('DELETE_PAYMENT', {'id': paymentId});
    notifyDataChanged();
  }

  Future<void> updateBedStatus(String bedId, BedStatus status) async {
    final beds = await _localService.getBeds();
    final index = beds.indexWhere((b) => b.bedId == bedId);
    if (index != -1) {
      await _enqueue(
          'UPDATE_BED_STATUS', {'bedId': bedId, 'status': status.toString()});
      notifyDataChanged();
    }
  }

  // --- Expenses ---

  Future<void> addExpense(ExpenseModel expense) async {
    final expenseWithId = expense.id == null || expense.id!.isEmpty
        ? expense.copyWith(id: const Uuid().v4())
        : expense;

    await _enqueue('ADD_EXPENSE', expenseWithId);
    notifyDataChanged();
  }

  Future<void> deleteExpense(String expenseId) async {
    await _enqueue('DELETE_EXPENSE', {'id': expenseId});
    notifyDataChanged();
  }

  Future<List<ExpenseModel>> getExpenses({bool forceRefresh = false}) async {
    final local = await _localService.getExpenses();
    if (!forceRefresh && local.isNotEmpty) return local;
    await triggerSync();
    return _localService.getExpenses();
  }

  // --- Getters (Local-First) ---

  Future<List<BuildingModel>> getBuildings({bool forceRefresh = false}) async {
    final local = await _localService.getBuildings();
    if (!forceRefresh && local.isNotEmpty) return local;
    await triggerSync();
    return _localService.getBuildings();
  }

  Future<List<RoomModel>> getRooms({bool forceRefresh = false}) async {
    final local = await _localService.getRooms();
    if (!forceRefresh && local.isNotEmpty) return local;
    await triggerSync();
    return _localService.getRooms();
  }

  Future<List<TenantModel>> getTenants({bool forceRefresh = false}) async {
    final local = await _localService.getTenants();
    if (!forceRefresh && local.isNotEmpty) return local;
    await triggerSync();
    return _localService.getTenants();
  }

  Future<List<PaymentModel>> getPayments({bool forceRefresh = false}) async {
    final local = await _localService.getPayments();
    if (!forceRefresh && local.isNotEmpty) return local;
    await triggerSync();
    return _localService.getPayments();
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

    await _enqueue('ADD_BED', bedWithId);
    notifyDataChanged();
  }

  Future<void> deleteBed(String bedId) async {
    await _enqueue('DELETE_BED', {'id': bedId});
    notifyDataChanged();
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
    final local = await _localService.getBeds();
    if (!forceRefresh && local.isNotEmpty) return local;
    await triggerSync();
    return _localService.getBeds();
  }
}
