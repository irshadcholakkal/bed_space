import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/building_model.dart';
import '../models/room_model.dart';
import '../models/tenant_model.dart';
import '../models/payment_model.dart';
import '../models/bed_model.dart';
import '../services/google_sheets_service.dart';
import '../services/local_database_service.dart';
import 'sheet_repository.dart';

class SyncWorker {
  static final SyncWorker _instance = SyncWorker._internal();
  factory SyncWorker() => _instance;
  SyncWorker._internal();

  bool _isProcessing = false;

  Future<bool> processQueue() async {
    if (_isProcessing) return false;

    // Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return false;

    // Get credentials
    final sheetRepo = SheetRepository();
    final sheetId = await sheetRepo.getSheetId();
    final token = await sheetRepo.getToken();

    if (sheetId == null || token == null) return false;

    _isProcessing = true;
    try {
      final localService = LocalDatabaseService();
      final sheetsService = GoogleSheetsService(
        accessToken: token,
        sheetId: sheetId,
      );

      final queue = await localService.getMutationQueue();
      if (queue.isEmpty) return true;

      for (final item in queue) {
        final success = await _processMutation(item, sheetsService);
        if (success) {
          await localService.removeFromQueue(item['id']);
        } else {
          final newCount = (item['retry_count'] as int) + 1;
          await localService.updateMutationRetryCount(item['id'], newCount);
          return false; // Stop immediately on failure
        }
      }

      // After successful queue processing, do a lightweight refresh
      await _syncSheetsToLocal(sheetsService, localService);
      return true;
    } catch (e) {
      print('SyncWorker Error: $e');
      return false;
    } finally {
      _isProcessing = false;
    }
  }

  Future<bool> _processMutation(Map<String, dynamic> item, GoogleSheetsService sheetsService) async {
    try {
      final type = item['type'] as String;
      final payload = jsonDecode(item['payload'] as String);

      switch (type) {
        case 'ADD_BUILDING':
          await sheetsService.addBuilding(BuildingModel.fromJson(payload));
          break;
        case 'UPDATE_BUILDING':
          await sheetsService.updateBuilding(BuildingModel.fromJson(payload));
          break;
        case 'DELETE_BUILDING':
          await sheetsService.deleteBuilding(payload['id']);
          break;
        case 'ADD_ROOM':
          await sheetsService.addRoom(RoomModel.fromJson(payload));
          break;
        case 'UPDATE_ROOM':
          await sheetsService.updateRoom(RoomModel.fromJson(payload));
          break;
        case 'DELETE_ROOM':
          await sheetsService.deleteRoom(payload['id']);
          break;
        case 'ADD_TENANT':
          await sheetsService.addTenant(TenantModel.fromJson(payload));
          break;
        case 'UPDATE_TENANT':
          await sheetsService.updateTenant(TenantModel.fromJson(payload));
          break;
        case 'DELETE_TENANT':
          await sheetsService.deleteTenant(payload['id']);
          break;
        case 'ADD_PAYMENT':
          await sheetsService.addPayment(PaymentModel.fromJson(payload));
          break;
        case 'DELETE_PAYMENT':
          await sheetsService.deletePayment(payload['id']);
          break;
        case 'UPDATE_BED_STATUS':
          await sheetsService.updateBedStatus(
            payload['bedId'], 
            BedStatus.values.firstWhere((e) => e.toString() == payload['status'])
          );
          break;
      }
      return true;
    } catch (e) {
      print('Mutation processing failed: $e');
      return false;
    }
  }

  Future<void> _syncSheetsToLocal(GoogleSheetsService sheetsService, LocalDatabaseService localService) async {
    try {
      final results = await Future.wait([
        sheetsService.getBuildings(),
        sheetsService.getRooms(),
        sheetsService.getTenants(),
        sheetsService.getPayments(),
        sheetsService.getBeds(),
      ]);

      await localService.saveBuildings(results[0] as List<BuildingModel>);
      await localService.saveRooms(results[1] as List<RoomModel>);
      await localService.saveTenants(results[2] as List<TenantModel>);
      await localService.savePayments(results[3] as List<PaymentModel>);
      await localService.saveBeds(results[4] as List<BedModel>);
    } catch (e) {
      print('Sync to local failed: $e');
    }
  }
}
