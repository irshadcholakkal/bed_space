import 'dart:async';
import '../services/google_sheets_service.dart';
import '../services/local_database_service.dart';
import '../models/building_model.dart';
import '../models/room_model.dart';
import '../models/tenant_model.dart';
import '../models/payment_model.dart';
import '../models/bed_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'sync_worker.dart';

class ManagementRepository {
  final GoogleSheetsService _sheetsService;
  final LocalDatabaseService _localService;

  final _dataChangeController = StreamController<void>.broadcast();
  StreamSubscription? _connectivitySubscription;
  bool _isProcessingQueue = false;

  ManagementRepository({
    required GoogleSheetsService sheetsService,
    LocalDatabaseService? localService,
  }) : _sheetsService = sheetsService,
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
    // Initial emission of local data
    Map<String, dynamic> currentData = await _getLocalData();
    currentData['source'] = 'local';
    yield currentData;

    // Background sync from sheets
    _syncSheetsToLocal();

    // Listen for any local data changes and yield updated local data
    await for (final _ in _dataChangeController.stream) {
      currentData = await _getLocalData();
      currentData['source'] = 'local_update';
      yield currentData;
    }
  }

  Future<Map<String, dynamic>> _getLocalData() async {
    final results = await Future.wait([
      _localService.getBuildings(),
      _localService.getRooms(),
      _localService.getTenants(),
      _localService.getPayments(),
      _localService.getBeds(),
    ]);

    return {
      'buildings': results[0] as List<BuildingModel>,
      'rooms': results[1] as List<RoomModel>,
      'tenants': results[2] as List<TenantModel>,
      'payments': results[3] as List<PaymentModel>,
      'beds': results[4] as List<BedModel>,
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
      ]);

      await _localService.saveBuildings(results[0] as List<BuildingModel>);
      await _localService.saveRooms(results[1] as List<RoomModel>);
      await _localService.saveTenants(results[2] as List<TenantModel>);
      await _localService.savePayments(results[3] as List<PaymentModel>);
      await _localService.saveBeds(results[4] as List<BedModel>);

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

    try {
      await _sheetsService.addBuilding(buildingWithId);
      await _syncSheetsToLocal();
    } catch (e) {
      await _enqueue('ADD_BUILDING', buildingWithId);
    }
  }

  Future<void> updateBuilding(BuildingModel building) async {
    await _localService.upsertBuilding(building);
    _dataChangeController.add(null);

    try {
      await _sheetsService.updateBuilding(building);
    } catch (e) {
      await _enqueue('UPDATE_BUILDING', building);
    }
  }

  Future<void> deleteBuilding(String id) async {
    await _localService.deleteBuildingLocal(id);
    _dataChangeController.add(null);

    try {
      await _sheetsService.deleteBuilding(id);
    } catch (e) {
      await _enqueue('DELETE_BUILDING', {'id': id});
    }
  }

  Future<void> addRoom(RoomModel room) async {
    final roomWithId = room.roomId == null || room.roomId!.isEmpty
        ? RoomModel(
            roomId: const Uuid().v4(),
            buildingId: room.buildingId,
            roomNumber: room.roomNumber,
            totalCapacity: room.totalCapacity,
            lowerBedsCount: room.lowerBedsCount,
            upperBedsCount: room.upperBedsCount,
            lowerBedRent: room.lowerBedRent,
            upperBedRent: room.upperBedRent,
            utilityCostMonthly: room.utilityCostMonthly,
          )
        : room;

    await _localService.upsertRoom(roomWithId);
    _dataChangeController.add(null);

    try {
      await _sheetsService.addRoom(roomWithId);
      await _syncSheetsToLocal();
    } catch (e) {
      await _enqueue('ADD_ROOM', roomWithId);
    }
  }

  Future<void> updateRoom(RoomModel room) async {
    await _localService.upsertRoom(room);
    _dataChangeController.add(null);

    try {
      await _sheetsService.updateRoom(room);
    } catch (e) {
      await _enqueue('UPDATE_ROOM', room);
    }
  }

  Future<void> deleteRoom(String id) async {
    await _localService.deleteRoomLocal(id);
    _dataChangeController.add(null);

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

    try {
      await _sheetsService.addTenant(tenantWithId);
      await _syncSheetsToLocal();
    } catch (e) {
      await _enqueue('ADD_TENANT', tenantWithId);
    }
  }

  Future<void> updateTenant(TenantModel tenant) async {
    await _localService.upsertTenant(tenant);
    _dataChangeController.add(null);

    try {
      await _sheetsService.updateTenant(tenant);
    } catch (e) {
      await _enqueue('UPDATE_TENANT', tenant);
    }
  }

  Future<void> deleteTenant(String id) async {
    await _localService.deleteTenantLocal(id);
    _dataChangeController.add(null);

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
    _syncPaymentToSheets(paymentWithId);
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

    try {
      await _sheetsService.updateBedStatus(bedId, status);
    } catch (e) {
      await _enqueue('UPDATE_BED_STATUS', {
        'bedId': bedId,
        'status': status.toString(),
      });
    }
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
    await _localService.upsertBed(bed);
    _dataChangeController.add(null);

    try {
      await _sheetsService.addBed(bed);
    } catch (e) {
      print('Add Bed Sync Error: $e');
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

    final now = DateTime.now();
    final joiningDate = tenant.joiningDate;
    final startMonth = DateTime(joiningDate.year, joiningDate.month);
    final currentMonth = DateTime(now.year, now.month);

    int monthsCount = 0;
    DateTime month = startMonth;
    while (month.isBefore(currentMonth) ||
        month.isAtSameMomentAs(currentMonth)) {
      monthsCount++;
      month = DateTime(month.year, month.month + 1);
    }

    final totalDue = tenant.rentAmount * monthsCount;
    final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
    final balance = totalDue - totalPaid;

    return {
      'totalDue': totalDue,
      'totalPaid': totalPaid,
      'balance': balance,
      'payments': payments,
      'tenant': tenant,
    };
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
