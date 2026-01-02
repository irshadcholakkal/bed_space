import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/models/tenant_model.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/building_model.dart';
import '../../../data/repositories/management_repository.dart';

part 'financial_event.dart';
part 'financial_state.dart';

class FinancialBloc extends Bloc<FinancialEvent, FinancialState> {
  final ManagementRepository _repository;

  FinancialBloc({required ManagementRepository repository})
    : _repository = repository,
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
        final rooms = data['rooms'] as List<RoomModel>;
        final buildings = data['buildings'] as List<BuildingModel>;

        final activeTenants = tenants.where((t) => t.active).toList();
        final monthPayments = payments
            .where((p) => p.paymentMonth == month)
            .toList();

        // Map room IDs to Room Numbers for easy lookup
        final roomMap = {for (var r in rooms) r.roomId!: r.roomNumber};
        // Map building IDs to Building Names
        final buildingMap = {
          for (var b in buildings) b.buildingId!: b.buildingName,
        };

        // Create tenant payment status
        final List<TenantPaymentStatus> tenantPayments = activeTenants.map((
          tenant,
        ) {
          // Find ALL payments for this tenant in this month
          final tenantMonthPayments = monthPayments
              .where((p) => p.tenantId == tenant.tenantId)
              .toList();

          // Calculate total paid amount by summing all payments
          final paidAmount = tenantMonthPayments.fold<double>(
            0,
            (sum, p) => sum + p.amount,
          );

          // Find the latest payment date if exists
          DateTime? lastPaidDate;
          if (tenantMonthPayments.isNotEmpty) {
            // Sort by date to get latest? Or just take the last entry?
            // Safest is to sort or reduce.
            lastPaidDate = tenantMonthPayments
                .map((p) => p.paidDate)
                .reduce((a, b) => a.isAfter(b) ? a : b);
          }

          final rentAmount = tenant.rentAmount;

          PaymentStatus status;
          if (paidAmount >= rentAmount) {
            status = PaymentStatus.paid;
          } else if (paidAmount > 0) {
            status = PaymentStatus.partial;
          } else {
            status = PaymentStatus.overdue;
          }

          final roomNumber = roomMap[tenant.roomId] ?? 'Unknown';
          final buildingName = buildingMap[tenant.buildingId] ?? 'Unknown';

          return TenantPaymentStatus(
            tenant: tenant,
            paidAmount: paidAmount,
            rentAmount: rentAmount,
            status: status,
            paidDate: lastPaidDate,
            roomNumber: roomNumber,
            buildingName: buildingName,
          );
        }).toList();

        // Calculate room-wise totals
        final Map<String, double> roomTotals = {};
        for (final payment in tenantPayments) {
          roomTotals[payment.tenant.roomId] =
              (roomTotals[payment.tenant.roomId] ?? 0) + payment.paidAmount;
        }

        // Calculate Expenses (Sum of utility cost for rooms that have at least one active tenant)
        // Or simply all rooms? Usually expenses are for the flat regardless.
        // Let's sum all rooms utility cost.
        final expenses = rooms.fold<double>(
          0,
          (sum, room) => sum + room.utilityCostMonthly,
        );

        // Calculate Total Collected
        final totalCollected = tenantPayments.fold<double>(
          0,
          (sum, tp) => sum + tp.paidAmount,
        );

        final profit = totalCollected - expenses;

        return FinancialLoaded(
          month: month,
          tenantPayments: tenantPayments,
          roomTotals: roomTotals,
          expenses: expenses,
          profit: profit,
        );
      },
      onError: (e, _) => FinancialError(e.toString()),
    );
  }
}

enum PaymentStatus { paid, partial, overdue }

class TenantPaymentStatus {
  final TenantModel tenant;
  final double paidAmount;
  final double rentAmount;
  final PaymentStatus status;
  final DateTime? paidDate;
  final String? roomNumber;
  final String? buildingName;

  // Helper
  bool get hasPaid => status == PaymentStatus.paid;

  TenantPaymentStatus({
    required this.tenant,
    required this.paidAmount,
    required this.rentAmount,
    required this.status,
    this.paidDate,
    this.roomNumber,
    this.buildingName,
  });
}
