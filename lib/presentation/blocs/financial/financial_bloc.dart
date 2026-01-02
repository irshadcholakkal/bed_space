import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/models/tenant_model.dart';
import '../../../data/models/room_model.dart';
import '../../../data/repositories/management_repository.dart';

part 'financial_event.dart';
part 'financial_state.dart';

class FinancialBloc extends Bloc<FinancialEvent, FinancialState> {
  final ManagementRepository _repository;

  FinancialBloc({
    required ManagementRepository repository,
  })  : _repository = repository,
        super(FinancialInitial()) {
    on<FinancialLoadRequested>(_onFinancialLoadRequested);
    on<FinancialMonthChanged>(_onFinancialMonthChanged);
  }

  Future<void> _onFinancialLoadRequested(
    FinancialLoadRequested event,
    Emitter<FinancialState> emit,
  ) async {
    emit(FinancialLoading());
    await _loadFinancialData(emit, event.month);
  }

  Future<void> _onFinancialMonthChanged(
    FinancialMonthChanged event,
    Emitter<FinancialState> emit,
  ) async {
    emit(FinancialLoading());
    await _loadFinancialData(emit, event.month);
  }

  Future<void> _loadFinancialData(
    Emitter<FinancialState> emit,
    String month,
  ) async {
    await emit.forEach<Map<String, dynamic>>(
      _repository.getAllDataStream(),
      onData: (data) {
        final tenants = data['tenants'] as List<TenantModel>;
        final payments = data['payments'] as List<PaymentModel>;

        final activeTenants = tenants.where((t) => t.active).toList();
        final monthPayments = payments.where((p) => p.paymentMonth == month).toList();

        // Create tenant payment status
        final List<TenantPaymentStatus> tenantPayments = activeTenants.map((tenant) {
          final payment = monthPayments.firstWhere(
            (p) => p.tenantId == tenant.tenantId,
            orElse: () => PaymentModel(
              tenantId: tenant.tenantId ?? '',
              amount: 0,
              paymentMonth: month,
              paidDate: DateTime.now(),
            ),
          );

          return TenantPaymentStatus(
            tenant: tenant,
            hasPaid: payment.paymentId != null && payment.amount > 0,
            amount: payment.amount > 0 ? payment.amount : tenant.rentAmount,
            paidDate: payment.paymentId != null ? payment.paidDate : null,
          );
        }).toList();

        // Calculate room-wise totals
        final Map<String, double> roomTotals = {};
        for (final tenant in activeTenants) {
          final payment = monthPayments.firstWhere(
            (p) => p.tenantId == tenant.tenantId,
            orElse: () => PaymentModel(
              tenantId: tenant.tenantId ?? '',
              amount: 0,
              paymentMonth: month,
              paidDate: DateTime.now(),
            ),
          );
          final amount = payment.amount > 0 ? payment.amount : tenant.rentAmount;
          roomTotals[tenant.roomId] = (roomTotals[tenant.roomId] ?? 0) + amount;
        }

        return FinancialLoaded(
          month: month,
          tenantPayments: tenantPayments,
          roomTotals: roomTotals,
        );
      },
      onError: (e, _) => FinancialError(e.toString()),
    );
  }
}

class TenantPaymentStatus {
  final TenantModel tenant;
  final bool hasPaid;
  final double amount;
  final DateTime? paidDate;

  TenantPaymentStatus({
    required this.tenant,
    required this.hasPaid,
    required this.amount,
    this.paidDate,
  });
}
