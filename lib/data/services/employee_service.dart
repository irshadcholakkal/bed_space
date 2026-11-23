import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'google_token_store.dart';
import 'saas_service.dart';

const employeePermissions = {
  'occupancy': 'View rooms and occupancy',
  'bookings': 'Manage bookings and occupancy',
  'collect_rent': 'Collect rent',
  'payment_history': 'View payment history',
  'void_payments': 'Void payments',
};

class EmployeeRequestException implements Exception {
  final String message;
  final int? status;
  const EmployeeRequestException(this.message, {this.status});
  @override
  String toString() => message;
}

class EmployeeService {
  static Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> fields = const {},
  ]) async {
    try {
      final result = await SaasService.client.functions
          .invoke('workspace-employees', body: {
        ...fields,
        'action': action
      }).timeout(const Duration(seconds: 45));
      return Map<String, dynamic>.from(result.data as Map);
    } on TimeoutException {
      throw const EmployeeRequestException('The connection timed out.',
          status: 0);
    } on FunctionException catch (error) {
      final details = error.details;
      throw EmployeeRequestException(
        details is Map && details['error'] is String
            ? details['error'] as String
            : 'Employee access is unavailable. Please try again.',
        status: error.status,
      );
    }
  }

  static Future<void> connect() async {
    final owner = SaasService.userId;
    final token =
        owner == null ? null : await GoogleTokenStore.readRefreshToken(owner);
    if (token == null || token.isEmpty) {
      throw const EmployeeRequestException(
        'Reconnect Google from Settings, then try again.',
      );
    }
    await call('connect', {'refresh_token': token});
  }

  static List<Map<String, dynamic>> rows(
          Map<String, dynamic> data, String key) =>
      (data[key] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
}
