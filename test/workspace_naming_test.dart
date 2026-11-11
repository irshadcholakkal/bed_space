import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bed_space/data/services/google_sheets_service.dart';
import 'package:bed_space/data/repositories/sheet_repository.dart';
import 'package:bed_space/presentation/blocs/sheet/sheet_bloc.dart';

class _Repository extends SheetRepository {
  String? saved;
  @override
  Future<void> saveSheetId(String sheetId, String userEmail,
      {String? driveFolderId}) async {
    saved = sheetId;
  }
}

void main() {
  test('New spreadsheet uses the business name', () async {
    final repository = _Repository();
    final client = MockClient((request) async {
      if (request.method == 'GET') return http.Response('{"files":[]}', 200);
      if (request.url.path == '/v4/spreadsheets') {
        expect(jsonDecode(request.body)['properties']['title'],
            "Palm's Living & Co");
        return http.Response('{"spreadsheetId":"new-sheet"}', 200);
      }
      return http.Response('{}', 200);
    });
    await http.runWithClient(() async {
      final bloc = SheetBloc(sheetRepository: repository);
      final ready =
          bloc.stream.firstWhere((s) => s is SheetCreated || s is SheetError);
      bloc.add(const SheetCreateRequested(
          accessToken: 'token',
          userEmail: 'owner@example.com',
          businessName: " Palm's Living & Co "));
      expect(await ready, isA<SheetCreated>());
      expect(repository.saved, 'new-sheet');
      await bloc.close();
    }, () => client);
  });
  test('Folder creation uses the business name and escapes Drive searches',
      () async {
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        expect(request.url.queryParameters['q'],
            contains(r"Palm\'s Living & Co - Documents"));
        expect(request.url.queryParameters['q'], contains('Bedspace_customer'));
        return http.Response('{"files":[]}', 200);
      }
      expect(
          jsonDecode(request.body)['name'], "Palm's Living & Co - Documents");
      return http.Response('{"id":"folder"}', 201);
    });
    await http.runWithClient(() async {
      expect(
          await GoogleSheetsService.ensureDocumentFolder('token', 'customer',
              businessName: "Palm's Living & Co"),
          'folder');
    }, () => client);
  });
  test('Existing business spreadsheet is reused on retry', () async {
    var searches = 0;
    final repository = _Repository();
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      searches++;
      if (searches == 1) return http.Response('{"files":[]}', 200);
      expect(
          request.url.queryParameters['q'], contains(r"Palm\'s Living & Co"));
      return http.Response('{"files":[{"id":"existing-sheet"}]}', 200);
    });
    await http.runWithClient(() async {
      final bloc = SheetBloc(sheetRepository: repository);
      final ready =
          bloc.stream.firstWhere((s) => s is SheetCreated || s is SheetError);
      bloc.add(const SheetCreateRequested(
          accessToken: 'token',
          userEmail: 'owner@example.com',
          businessName: "Palm's Living & Co"));
      expect(await ready, isA<SheetCreated>());
      expect(repository.saved, 'existing-sheet');
      await bloc.close();
    }, () => client);
  });
}
