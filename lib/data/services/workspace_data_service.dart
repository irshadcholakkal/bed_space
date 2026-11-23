import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'google_auth_service.dart';
import 'saas_service.dart';

class WorkspaceDataException implements Exception {
  final String message;
  const WorkspaceDataException(this.message);
}

class WorkspaceDataService {
  final String _sheetId;
  final String? _owner = SaasService.userId;
  WorkspaceDataService(this._sheetId);

  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> fields = const {},
  }) async {
    if (_owner == null || _owner != SaasService.userId) {
      throw const WorkspaceDataException(
          'Sign in again to manage workspace data.');
    }
    final token = await GoogleAuthService().signInSilently();
    if (token == null || _owner != SaasService.userId) {
      throw const WorkspaceDataException('Reconnect Google and try again.');
    }
    try {
      final response = await SaasService.client.functions.invoke(
        'workspace-backups',
        body: {
          ...fields,
          'action': action,
          'access_token': token,
          'spreadsheet_id': _sheetId,
        },
      ).timeout(const Duration(seconds: 90));
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      final details = error.details;
      throw WorkspaceDataException(details is Map && details['error'] is String
          ? details['error'] as String
          : 'Could not reach the workspace data service.');
    } on TimeoutException {
      throw const WorkspaceDataException(
        'The workspace data request timed out. Check the data before retrying.',
      );
    }
  }
}
