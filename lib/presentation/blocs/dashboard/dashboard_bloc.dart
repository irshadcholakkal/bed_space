import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/building_model.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/bed_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/models/tenant_model.dart';
import '../../../data/repositories/management_repository.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final ManagementRepository _repository;

  DashboardBloc({
    required ManagementRepository repository,
  })  : _repository = repository,
        super(DashboardInitial()) {
    on<DashboardLoadRequested>(_onDashboardLoadRequested);
  }

  Future<void> _onDashboardLoadRequested(
    DashboardLoadRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());

    await emit.forEach<Map<String, dynamic>>(
      _repository.getAllDataStream(),
      onData: (data) {
        final buildings = data['buildings'] as List<BuildingModel>;
        final rooms = data['rooms'] as List<RoomModel>;
        final beds = data['beds'] as List<BedModel>;
        final tenants = data['tenants'] as List<TenantModel>;
        final payments = data['payments'] as List<PaymentModel>;

        // Calculate statistics
        final totalBeds = beds.length;
        final occupiedBeds = beds.where((b) => b.status == BedStatus.occupied).length;
        final vacantBeds = totalBeds - occupiedBeds;

        // Current month calculations
        final now = DateTime.now();
        final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final currentMonthPayments =
            payments.where((p) => p.paymentMonth == currentMonth).toList();
        final rentCollected =
            currentMonthPayments.fold<double>(0, (sum, p) => sum + p.amount);

        // Calculate utility expenses
        final utilityExpenses = rooms.fold<double>(
          0,
          (sum, room) => sum + room.utilityCostMonthly,
        );

        final profit = rentCollected - utilityExpenses;

        return DashboardLoaded(
          totalBuildings: buildings.length,
          totalRooms: rooms.length,
          totalBeds: totalBeds,
          occupiedBeds: occupiedBeds,
          vacantBeds: vacantBeds,
          rentCollected: rentCollected,
          utilityExpenses: utilityExpenses,
          profit: profit,
        );
      },
      onError: (e, _) => DashboardError(e.toString()),
    );
  }
}
