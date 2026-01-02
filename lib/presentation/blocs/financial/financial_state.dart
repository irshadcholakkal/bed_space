part of 'financial_bloc.dart';

abstract class FinancialState extends Equatable {
  const FinancialState();

  @override
  List<Object> get props => [];
}

class FinancialInitial extends FinancialState {}

class FinancialLoading extends FinancialState {}

class FinancialLoaded extends FinancialState {
  final String month;
  final List<TenantPaymentStatus> tenantPayments;
  final Map<String, double> roomTotals;
  final double expenses;
  final double profit;

  const FinancialLoaded({
    required this.month,
    required this.tenantPayments,
    required this.roomTotals,
    this.expenses = 0.0,
    this.profit = 0.0,
  });

  @override
  List<Object> get props => [
    month,
    tenantPayments,
    roomTotals,
    expenses,
    profit,
  ];
}

class FinancialError extends FinancialState {
  final String message;

  const FinancialError(this.message);

  @override
  List<Object> get props => [message];
}
