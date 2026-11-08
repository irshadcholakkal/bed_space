import 'dart:convert';

import 'package:bed_space/data/models/bed_model.dart';
import 'package:bed_space/data/models/expense_model.dart';
import 'package:bed_space/data/repositories/sync_worker.dart';
import 'package:bed_space/data/services/google_sheets_service.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingSheetsService extends GoogleSheetsService {
  RecordingSheetsService() : super(accessToken: '', sheetId: '');

  ExpenseModel? expense;
  BedModel? bed;
  String? deletedExpense;
  bool fail = false;

  @override
  Future<void> addExpense(ExpenseModel value) async {
    if (fail) throw StateError('Offline');
    expense = value;
  }

  @override
  Future<void> deleteExpense(String id) async => deletedExpense = id;

  @override
  Future<void> addBed(BedModel value) async => bed = value;
}

void main() {
  late RecordingSheetsService sheets;
  setUp(() => sheets = RecordingSheetsService());

  Future<bool> run(String type, Map<String, dynamic> payload) =>
      SyncWorker().processMutation({
        'type': type,
        'payload': jsonEncode(payload),
      }, sheets);

  test('queued expenses preserve tenant and refund details', () async {
    final expense = ExpenseModel(
      id: 'expense-1',
      roomId: 'room-1',
      tenantId: 'tenant-1',
      expenseType: ExpenseType.refund,
      amount: 125,
      date: DateTime(2026, 11, 8),
    );
    expect(await run('ADD_EXPENSE', expense.toJson()), isTrue);
    expect(sheets.expense!.toJson(), expense.toJson());
    expect(await run('DELETE_EXPENSE', {'id': expense.id}), isTrue);
    expect(sheets.deletedExpense, expense.id);
  });

  test('queued bed additions reach Sheets', () async {
    final bed = BedModel(
        bedId: 'bed-1',
        roomId: 'room-1',
        bedType: BedType.lower,
        status: BedStatus.vacant);
    expect(await run('ADD_BED', bed.toJson()), isTrue);
    expect(sheets.bed!.toJson(), bed.toJson());
  });

  test('failed and unsupported mutations remain eligible for retry', () async {
    sheets.fail = true;
    final expense = ExpenseModel(
        roomId: 'room-1',
        expenseType: ExpenseType.other,
        amount: 10,
        date: DateTime(2026));
    expect(await run('ADD_EXPENSE', expense.toJson()), isFalse);
    expect(await run('UNSUPPORTED', {}), isFalse);
  });

  test('expense copies retain or replace the tenant association', () {
    final expense = ExpenseModel(
        roomId: 'room-1',
        tenantId: 'tenant-1',
        expenseType: ExpenseType.refund,
        amount: 10,
        date: DateTime(2026));
    expect(expense.copyWith(amount: 20).tenantId, 'tenant-1');
    expect(expense.copyWith(tenantId: 'tenant-2').tenantId, 'tenant-2');
  });
}
