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

  const FinancialLoaded({
    required this.month,
    required this.tenantPayments,
    required this.roomTotals,
  });

  @override
  List<Object> get props => [month, tenantPayments, roomTotals];
}

class FinancialError extends FinancialState {
  final String message;

  const FinancialError(this.message);

  @override
  List<Object> get props => [message];
}

