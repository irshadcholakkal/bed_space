import '../models/booking_model.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/building_model.dart';
import '../models/room_model.dart';
import '../models/tenant_model.dart';
import '../models/payment_model.dart';
import '../models/bed_model.dart';
import '../models/expense_model.dart';
import '../services/google_sheets_service.dart';
import '../services/local_database_service.dart';
import 'sheet_repository.dart';
import '../services/saas_service.dart';

class SyncWorker {
  static final SyncWorker _instance = SyncWorker._internal();
  factory SyncWorker() => _instance;
  SyncWorker._internal();

  Future<bool>? _processing;

  Future<bool> processQueue(
      {GoogleSheetsService? sheetsService,
      LocalDatabaseService? localService}) {
    return _processing ??= _processQueue(sheetsService, localService)
        .whenComplete(() => _processing = null);
  }

  Future<bool> _processQueue(GoogleSheetsService? sheetsService,
      LocalDatabaseService? localService) async {
    if (SaasService.configured && SaasService.userId == null) return false;

    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return false;

      if (sheetsService == null || localService == null) {
        final sheetRepo = SheetRepository();
        final sheetId = await sheetRepo.getSheetId();
        final token = await sheetRepo.getToken();
        if (sheetId == null || token == null) return false;
        await LocalDatabaseService.selectWorkspace(sheetId);
        localService = LocalDatabaseService();
        sheetsService =
            GoogleSheetsService(accessToken: token, sheetId: sheetId);
      }

      while (true) {
        final queue = await localService.getMutationQueue();
        if (queue.isEmpty) return true;

        for (final item in queue) {
          final success = await processMutation(item, sheetsService);
          if (success) {
            await localService.removeFromQueue(item['id']);
          } else {
            final newCount = (item['retry_count'] as int) + 1;
            await localService.updateMutationRetryCount(item['id'], newCount);
            return false; // Stop immediately on failure
          }
        }
      }
    } catch (e) {
      developer.log('SyncWorker Error: $e');
      return false;
    }
  }

  @visibleForTesting
  Future<bool> processMutation(
      Map<String, dynamic> item, GoogleSheetsService sheetsService) async {
    try {
      final type = item['type'] as String;
      final payload = jsonDecode(item['payload'] as String);

      switch (type) {
        case 'ADD_BOOKING':
          final booking = BookingModel.fromJson(payload);
          await sheetsService.saveBooking(booking);
          if (booking.rentPayment != null) {
            await sheetsService.addPayment(booking.rentPayment!);
          }
          break;
        case 'CHECK_IN_BOOKING':
          final booking = BookingModel.fromJson(payload);
          await sheetsService.addTenant(booking.toTenant());
          await sheetsService.updateBedStatus(
              booking.bedId, BedStatus.occupied);
          await sheetsService.saveBooking(booking);
          break;
        case 'CANCEL_BOOKING':
          await sheetsService
              .saveBooking(BookingModel.fromJson(payload['booking']));
          if (payload['expense'] != null) {
            await sheetsService
                .addExpense(ExpenseModel.fromJson(payload['expense']));
          }
          break;
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
              BedStatus.values
                  .firstWhere((e) => e.toString() == payload['status']));
          break;
        case 'DELETE_BED':
          await sheetsService.deleteBed(payload['id']);
          break;
        case 'ADD_BED':
          await sheetsService.addBed(BedModel.fromJson(payload));
          break;
        case 'ADD_EXPENSE':
          await sheetsService.addExpense(ExpenseModel.fromJson(payload));
          break;
        case 'DELETE_EXPENSE':
          await sheetsService.deleteExpense(payload['id']);
          break;
        default:
          throw UnsupportedError('Unknown mutation type: $type');
      }
      return true;
    } catch (e) {
      developer.log('Mutation processing failed: $e');
      return false;
    }
  }
}
