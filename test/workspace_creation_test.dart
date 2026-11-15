import 'dart:convert';
import 'package:bed_space/data/services/google_sheets_service.dart';
import 'package:bed_space/presentation/blocs/sheet/sheet_bloc.dart';
import 'package:bed_space/data/repositories/sheet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Repository extends SheetRepository {
  String? saved;
  @override
  Future<void> saveSheetId(String sheetId, String userEmail,
          {String? driveFolderId}) async =>
      saved = sheetId;
}

void main() {
  test('creates spreadsheet with all seven header rows and saves workspace',
      () async {
    final headers = <String>[];
    final repository = _Repository();
    final states = <SheetState>[];
    await http.runWithClient(() async {
      final bloc = SheetBloc(sheetRepository: repository);
      addTearDown(bloc.close);
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);
      final done =
          bloc.stream.firstWhere((s) => s is SheetCreated || s is SheetError);
      bloc.add(const SheetCreateRequested(
          accessToken: 'setup-token',
          userEmail: 'owner@example.com',
          businessName: 'Palm Living'));
      expect(await done, isA<SheetCreated>());
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer setup-token');
              if (request.url.host == 'www.googleapis.com') {
                return http.Response('{"files":[]}', 200);
              }
              if (request.method == 'POST') {
                final body = jsonDecode(request.body);
                expect(body['properties']['title'], 'Palm Living');
                expect(body['sheets'], hasLength(7));
                return http.Response('{"spreadsheetId":"new-sheet"}', 200);
              }
              expect(request.method, 'PUT');
              expect(jsonDecode(request.body)['values'], isNotEmpty);
              headers.add(request.url.path);
              return http.Response('{}', 200);
            }));
    expect(headers, hasLength(7));
    expect(repository.saved, 'new-sheet');
    expect(states.whereType<SheetSetupProgress>().map((s) => s.progress),
        [.35, .50, .75, .90]);
  });

  test('creates document folder and reuses it on retry', () async {
    var created = false;
    var creations = 0;
    await http.runWithClient(() async {
      for (var i = 0; i < 2; i++) {
        expect(
            await GoogleSheetsService.ensureDocumentFolder('token', 'owner',
                businessName: 'Palm Living'),
            'folder-id');
      }
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer token');
              if (request.method == 'GET') {
                return http.Response(
                    jsonEncode({
                      'files': [
                        if (created) {'id': 'folder-id'}
                      ]
                    }),
                    200);
              }
              expect(
                  jsonDecode(request.body)['name'], 'Palm Living');
              created = true;
              creations++;
              return http.Response('{"id":"folder-id"}', 201);
            }));
    expect(creations, 1);
  });

  test('Drive search failure stops creation and never saves a broken link',
      () async {
    final repository = _Repository();
    await http.runWithClient(() async {
      final bloc = SheetBloc(sheetRepository: repository);
      addTearDown(bloc.close);
      final failed = bloc.stream.firstWhere((s) => s is SheetError);
      bloc.add(const SheetCreateRequested(
          accessToken: 'token',
          userEmail: 'owner@example.com',
          businessName: 'Palm Living'));
      expect((await failed as SheetError).message, contains('search'));
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              return http.Response(
                  '{"error":{"message":"Drive API disabled"}}', 403);
            }));
    expect(repository.saved, isNull);
  });
}
