import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bed_space/data/services/business_profile_service.dart';

void main() {
  for (final missingCode in [null, '42703', 'PGRST204']) {
    test('Save and restore business details with profile schema $missingCode',
        () async {
      final patches = <Map<String, dynamic>>[];
      Map<String, dynamic> metadata = {};
      final user = <String, dynamic>{
        'id': 'customer-id',
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'owner@example.com',
        'created_at': '2026-11-01T00:00:00Z',
        'app_metadata': {},
        'user_metadata': metadata,
      };
      final client = SupabaseClient('https://example.supabase.co', 'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          return http.Response(
              jsonEncode({
                'access_token': 'test-token',
                'refresh_token': 'refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': user
              }),
              200);
        }
        if (request.url.path.endsWith('/user')) {
          metadata = Map<String, dynamic>.from(
              jsonDecode(request.body)['data'] as Map);
          user['user_metadata'] = metadata;
          return http.Response(jsonEncode(user), 200);
        }
        if (request.method == 'PATCH') {
          final body =
              Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          patches.add(body);
          expect(request.url.queryParameters['user_id'], 'eq.customer-id');
          if (missingCode != null && body.containsKey('phone_number')) {
            return http.Response(
                jsonEncode({
                  'code': missingCode,
                  'message': 'column profiles.phone_number does not exist'
                }),
                400,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('', 204,
              request: request, headers: {'content-type': 'application/json'});
        }
        if (request.method == 'GET') {
          if (missingCode != null &&
              request.url.queryParameters['select']!.contains('phone_number')) {
            return http.Response(
                jsonEncode({
                  'code': missingCode,
                  'message': 'phone_number missing from schema cache'
                }),
                400,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          return http.Response(
              jsonEncode([
                {'business_name': 'Old name'}
              ]),
              200,
              request: request,
              headers: {'content-type': 'application/json'});
        }
        throw StateError(
            'Unexpected request ${request.method} ${request.url.path}');
      }));
      addTearDown(client.dispose);
      await client.auth
          .signInWithPassword(email: 'owner@example.com', password: 'password');
      final service = BusinessProfileService(client);
      await service.save(
          businessName: ' Palm Living ', phoneNumber: ' +971501234567 ');
      expect(metadata,
          {'business_name': 'Palm Living', 'phone_number': '+971501234567'});
      expect(patches.length, missingCode == null ? 1 : 2);
      if (missingCode != null) {
        expect(patches.last, {'business_name': 'Palm Living'});
      }
      final restored = await service.load();
      expect(restored['business_name'], 'Palm Living');
      expect(restored['phone_number'], '+971501234567');
    });
  }
  test('Profile permission errors remain actionable', () {
    expect(
        BusinessProfileService.errorMessage(
            const PostgrestException(message: 'denied', code: '42501')),
        contains('profile access is not configured'));
  });
}
