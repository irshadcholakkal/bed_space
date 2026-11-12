import 'expense_model.dart';
import 'payment_model.dart';
import 'room_model.dart';
import 'tenant_model.dart';

class PropertyTotals {
  final double income;
  final double expenses;
  const PropertyTotals({this.income = 0, this.expenses = 0});
  double get net => income - expenses;
}

class PropertyTransaction {
  final String title;
  final String roomId;
  final DateTime date;
  final double amount;
  final bool isIncome;
  const PropertyTransaction(
      {required this.title,
      required this.roomId,
      required this.date,
      required this.amount,
      required this.isIncome});
}

/// Reports actual recorded payments and expenses, never estimated room rents.
/// Payments follow their rent month; expenses follow their transaction date.
class PropertyFinancials {
  final List<RoomModel> rooms;
  final List<TenantModel> tenants;
  final List<PaymentModel> payments;
  final List<ExpenseModel> expenses;
  final String? month;
  const PropertyFinancials(
      {required this.rooms,
      required this.tenants,
      required this.payments,
      required this.expenses,
      this.month});

  Set<String> roomIds(
      {String? buildingId, String? roomId, bool includeSubrooms = true}) {
    if (roomId != null) {
      final selected = rooms.where((r) => r.roomId == roomId).firstOrNull;
      if (selected == null) return {};
      return {
        roomId,
        if (includeSubrooms && !selected.isSubroom)
          ...rooms
              .where((r) =>
                  r.parentRoomId == roomId &&
                  r.buildingId == selected.buildingId)
              .map((r) => r.roomId)
              .whereType<String>()
      };
    }
    return rooms
        .where((r) => buildingId == null || r.buildingId == buildingId)
        .map((r) => r.roomId)
        .whereType<String>()
        .toSet();
  }

  List<PropertyTransaction> transactions(Set<String> ids) {
    final tenantMap = {
      for (final tenant in tenants)
        if (tenant.tenantId != null) tenant.tenantId!: tenant
    };
    final result = <PropertyTransaction>[];
    for (final payment in payments) {
      final tenant = tenantMap[payment.tenantId];
      if (tenant == null ||
          !ids.contains(tenant.roomId) ||
          (month != null && payment.paymentMonth != month)) {
        continue;
      }
      result.add(PropertyTransaction(
          title: '${tenant.tenantName} · Rent payment',
          roomId: tenant.roomId,
          date: payment.paidDate,
          amount: payment.amount,
          isIncome: true));
    }
    for (final expense in expenses) {
      final expenseMonth =
          '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';
      if (!ids.contains(expense.roomId) ||
          (month != null && expenseMonth != month)) {
        continue;
      }
      result.add(PropertyTransaction(
          title: expense.displayName,
          roomId: expense.roomId,
          date: expense.date,
          amount: expense.amount,
          isIncome: false));
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  PropertyTotals totals(Set<String> ids) {
    double income = 0;
    double costs = 0;
    for (final entry in transactions(ids)) {
      if (entry.isIncome) {
        income += entry.amount;
      } else {
        costs += entry.amount;
      }
    }
    return PropertyTotals(income: income, expenses: costs);
  }
}
