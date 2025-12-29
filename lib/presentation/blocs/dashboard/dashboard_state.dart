part of 'dashboard_bloc.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object> get props => [];
}

class DashboardInitial extends DashboardState {}


class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final int totalBuildings;
  final int totalRooms;
  final int totalBeds;
  final int occupiedBeds;
  final int vacantBeds;
  final double rentCollected;
  final double utilityExpenses;
  final double profit;

  const DashboardLoaded({
    required this.totalBuildings,
    required this.totalRooms,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.vacantBeds,
    required this.rentCollected,
    required this.utilityExpenses,
    required this.profit,
  });

  @override
  List<Object> get props => [
        totalBuildings,
        totalRooms,
        totalBeds,
        occupiedBeds,
        vacantBeds,
        rentCollected,
        utilityExpenses,
        profit,
      ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object> get props => [message];
}

