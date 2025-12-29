import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/models/building_model.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/bed_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/models/tenant_model.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final GoogleSheetsService _sheetsService;

  DashboardBloc({
    required GoogleSheetsService sheetsService,
  })  : _sheetsService = sheetsService,
        super(DashboardInitial()) {
    on<DashboardLoadRequested>(_onDashboardLoadRequested);
  }

  Future<void> _onDashboardLoadRequested(
    DashboardLoadRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    try {
      final buildings = await _sheetsService.getBuildings();
      final rooms = await _sheetsService.getRooms();
      final beds = await _sheetsService.getBeds();
      final tenants = await _sheetsService.getTenants();
      final payments = await _sheetsService.getPayments();

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

      // Calculate utility expenses (sum of all rooms utility costs)
      final utilityExpenses = rooms.fold<double>(
        0,
        (sum, room) => sum + room.utilityCostMonthly,
      );

      final profit = rentCollected - utilityExpenses;

      emit(DashboardLoaded(
        totalBuildings: buildings.length,
        totalRooms: rooms.length,
        totalBeds: totalBeds,
        occupiedBeds: occupiedBeds,
        vacantBeds: vacantBeds,
        rentCollected: rentCollected,
        utilityExpenses: utilityExpenses,
        profit: profit,
      ));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}

