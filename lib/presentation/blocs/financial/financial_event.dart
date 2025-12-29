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

