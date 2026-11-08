part of 'financial_bloc.dart';

abstract class FinancialEvent extends Equatable {
  const FinancialEvent();

  @override
  List<Object> get props => [];
}

class FinancialLoadRequested extends FinancialEvent {
  final String month;

  const FinancialLoadRequested({required this.month});

  @override
  List<Object> get props => [month];
}

class FinancialMonthChanged extends FinancialEvent {
  final String month;

  const FinancialMonthChanged(this.month);

  @override
  List<Object> get props => [month];
}

class FinancialDataUpdated extends FinancialEvent {
  final String month;
  final List<TenantPaymentStatus> tenantPayments;
  final Map<String, double> roomTotals;
  final double expenses;
  final double totalRefunds;
  final double profit;
  final List<ExpenseModel> monthExpenses;

  const FinancialDataUpdated({
    required this.month,
    required this.tenantPayments,
    required this.roomTotals,
    required this.expenses,
    required this.totalRefunds,
    required this.profit,
    required this.monthExpenses,
  });

  @override
  List<Object> get props => [
        month,
        tenantPayments,
        roomTotals,
        expenses,
        totalRefunds,
        profit,
        monthExpenses,
      ];
}
