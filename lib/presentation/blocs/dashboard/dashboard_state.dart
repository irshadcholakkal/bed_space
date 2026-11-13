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
  final int availableRooms;
  final int reservedBeds;
  final double rentCollected;
  final double totalExpenses;
  final double profit;

  const DashboardLoaded({
    required this.totalBuildings,
    required this.totalRooms,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.vacantBeds,
    this.availableRooms = 0,
    this.reservedBeds = 0,
    required this.rentCollected,
    required this.totalExpenses,
    required this.profit,
  });

  @override
  List<Object> get props => [
        totalBuildings,
        totalRooms,
        totalBeds,
        occupiedBeds,
        vacantBeds,
        availableRooms,
        reservedBeds,
        rentCollected,
        totalExpenses,
        profit,
      ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object> get props => [message];
}
