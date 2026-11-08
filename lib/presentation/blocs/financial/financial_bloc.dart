import '../../../data/models/billing_snapshot.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/models/tenant_model.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/building_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/management_repository.dart';
import 'package:intl/intl.dart';

part 'financial_event.dart';
part 'financial_state.dart';

class FinancialBloc extends Bloc<FinancialEvent, FinancialState> {
  final ManagementRepository _repository;
  StreamSubscription? _dataSubscription;

  FinancialBloc({required ManagementRepository repository})
      : _repository = repository,
        super(FinancialInitial()) {
    on<FinancialLoadRequested>(_onFinancialLoadRequested);
    on<FinancialMonthChanged>(_onFinancialMonthChanged);
    on<FinancialDataUpdated>(_onFinancialDataUpdated);
  }

  @override
  Future<void> close() {
    _dataSubscription?.cancel();
    return super.close();
  }

  Future<void> _onFinancialLoadRequested(
    FinancialLoadRequested event,
    Emitter<FinancialState> emit,
  ) async {
    // Show loading only if we don't have a state yet
    if (state is! FinancialLoaded) {
      emit(FinancialLoading());
    }

    // Background sync - don't wait for it
    unawaited(_repository.syncWithSheets());

    _startDataSubscription(event.month);
  }

  Future<void> _onFinancialMonthChanged(
    FinancialMonthChanged event,
    Emitter<FinancialState> emit,
  ) async {
    // Only show full-screen loading if switching to a month we haven't loaded yet
    if (state is! FinancialLoaded ||
        (state as FinancialLoaded).month != event.month) {
      emit(FinancialLoading());
    }

    // Background sync - don't wait for it
    unawaited(_repository.syncWithSheets());

    _startDataSubscription(event.month);
  }

  void _onFinancialDataUpdated(
    FinancialDataUpdated event,
    Emitter<FinancialState> emit,
  ) {
    emit(FinancialLoaded(
      month: event.month,
      tenantPayments: event.tenantPayments,
      roomTotals: event.roomTotals,
      expenses: event.expenses,
      totalRefunds: event.totalRefunds,
      profit: event.profit,
      monthExpenses: event.monthExpenses,
    ));
  }

  void _startDataSubscription(String month) {
    _dataSubscription?.cancel();
    _dataSubscription = _repository.getAllDataStream().listen(
      (data) {
        final tenants = data['tenants'] as List<TenantModel>;
        final payments = data['payments'] as List<PaymentModel>;
        final rooms = data['rooms'] as List<RoomModel>;
        final buildings = data['buildings'] as List<BuildingModel>;

        final roomMap = {for (var r in rooms) r.roomId!: r.displayName(rooms)};
        final buildingMap = {
          for (var b in buildings) b.buildingId!: b.buildingName,
        };

        // Parse month for range checks
        final parts = month.split('-');
        final year = int.parse(parts[0]);
        final mon = int.parse(parts[1]);
        final firstOfMonth = DateTime(year, mon, 1);
        final firstOfNextMonth = DateTime(year, mon + 1, 1);

        // All tenants who were present in this month OR had a payment this month
        final monthPayments =
            payments.where((p) => p.paymentMonth == month).toList();
        final payingTenantIds = monthPayments.map((p) => p.tenantId).toSet();

        final relevantTenants = tenants.where((t) {
          // 1. If they have payments this month, they are relevant
          if (payingTenantIds.contains(t.tenantId)) return true;

          // 2. If they joined AFTER this month, they are NOT relevant
          if (t.joiningDate.isAfter(firstOfNextMonth) ||
              t.joiningDate.isAtSameMomentAs(firstOfNextMonth)) {
            return false;
          }

          // 3. If they are active, they are relevant (since they joined before end of month)
          if (t.active) return true;

          // 4. If they are inactive but checked out DURING or AFTER this month, they are relevant
          if (t.checkoutDate != null) {
            final checkout = t.checkoutDate!;
            if (checkout.isAfter(firstOfMonth) ||
                checkout.isAtSameMomentAs(firstOfMonth)) {
              return true;
            }
          }

          return false;
        }).toList();

        final List<TenantPaymentStatus> tenantPaymentsStatuses =
            relevantTenants.map((tenant) {
          final tenantMonthPayments = monthPayments
              .where((p) => p.tenantId == tenant.tenantId)
              .toList();

          final paidAmount = tenantMonthPayments.fold<double>(
            0,
            (sum, p) => sum + p.amount,
          );

          DateTime? lastPaidDate;
          if (tenantMonthPayments.isNotEmpty) {
            lastPaidDate = tenantMonthPayments
                .map((p) => p.paidDate)
                .reduce((a, b) => a.isAfter(b) ? a : b);
          }

          final rentAmount = BillingSnapshot.rentForMonth(tenant, firstOfMonth);

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

        final Map<String, double> roomTotals = {};
        for (final payment in monthPayments) {
          final tenant = tenants.firstWhere(
            (t) => t.tenantId == payment.tenantId,
            orElse: () => TenantModel(
              tenantName: 'Unknown',
              phone: '',
              joiningDate: DateTime.now(),
              rentAmount: 0,
              advanceAmount: 0,
              roomId: 'Unknown',
              buildingId: '',
              bedId: '',
              rentDueDay: 1,
              active: false,
            ),
          );
          roomTotals[tenant.roomId] =
              (roomTotals[tenant.roomId] ?? 0) + payment.amount;
        }

        final monthExpensesList = data['expenses'] as List<ExpenseModel>;
        final relevantExpenses = monthExpensesList
            .where((e) => DateFormat('yyyy-MM').format(e.date) == month)
            .toList();

        final expensesTotal = relevantExpenses
            .where((e) => e.expenseType != ExpenseType.refund)
            .fold<double>(0, (sum, e) => sum + e.amount);

        final totalRefunds = relevantExpenses
            .where((e) => e.expenseType == ExpenseType.refund)
            .fold<double>(0, (sum, e) => sum + e.amount);

        final grossCollected = monthPayments.fold<double>(
          0,
          (sum, p) => sum + p.amount,
        );

        // Profit = Gross - Expenses - Refunds
        final profit = grossCollected - expensesTotal - totalRefunds;

        add(FinancialDataUpdated(
          month: month,
          tenantPayments: tenantPaymentsStatuses,
          roomTotals: roomTotals,
          expenses: expensesTotal,
          totalRefunds: totalRefunds,
          profit: profit,
          monthExpenses: relevantExpenses,
        ));
      },
      onError: (e) {
        // Error handled silently as data will eventually sync
      },
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
