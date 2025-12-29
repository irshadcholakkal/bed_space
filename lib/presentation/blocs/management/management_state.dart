part of 'management_bloc.dart';

abstract class ManagementState extends Equatable {
  const ManagementState();

  @override
  List<Object> get props => [];
}
 

class ManagementInitial extends ManagementState {}

class ManagementLoading extends ManagementState {}

class BuildingsLoaded extends ManagementState {
  final List<BuildingModel> buildings;

  const BuildingsLoaded({required this.buildings});

  @override
  List<Object> get props => [buildings];
}

class RoomsLoaded extends ManagementState {
  final List<RoomModel> rooms;

  const RoomsLoaded({required this.rooms});

  @override
  List<Object> get props => [rooms];
}

class TenantsLoaded extends ManagementState {
  final List<TenantModel> tenants;

  const TenantsLoaded({required this.tenants});

  @override
  List<Object> get props => [tenants];
}

class PaymentsLoaded extends ManagementState {
  final List<PaymentModel> payments;

  const PaymentsLoaded({required this.payments});

  @override
  List<Object> get props => [payments];
}

class TenantBalanceLoaded extends ManagementState {
  final Map<String, dynamic> balance;

  const TenantBalanceLoaded({required this.balance});

  @override
  List<Object> get props => [balance];
}

class ManagementError extends ManagementState {
  final String message;

  const ManagementError(this.message);

  @override
  List<Object> get props => [message];
}

