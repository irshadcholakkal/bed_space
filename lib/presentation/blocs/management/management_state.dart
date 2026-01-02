part of 'management_bloc.dart';

abstract class ManagementState extends Equatable {
  const ManagementState();

  @override
  List<Object?> get props => [];
}

class ManagementInitial extends ManagementState {}

class ManagementLoaded extends ManagementState {
  final bool isLoading;
  final String? error;
  final List<BuildingModel> buildings;
  final List<RoomModel> rooms;
  final List<TenantModel> tenants;
  final List<PaymentModel> payments;
  final List<BedModel> beds;
  final Map<String, dynamic> tenantBalance;

  const ManagementLoaded({
    this.isLoading = false,
    this.error,
    this.buildings = const [],
    this.rooms = const [],
    this.tenants = const [],
    this.payments = const [],
    this.beds = const [],
    this.tenantBalance = const {},
  });

  ManagementLoaded copyWith({
    bool? isLoading,
    String? error,
    List<BuildingModel>? buildings,
    List<RoomModel>? rooms,
    List<TenantModel>? tenants,
    List<PaymentModel>? payments,
    List<BedModel>? beds,
    Map<String, dynamic>? tenantBalance,
  }) {
    return ManagementLoaded(
      isLoading: isLoading ?? this.isLoading,
      error: error, // error is not persisted by default, unless explicitly passed
      buildings: buildings ?? this.buildings,
      rooms: rooms ?? this.rooms,
      tenants: tenants ?? this.tenants,
      payments: payments ?? this.payments,
      beds: beds ?? this.beds,
      tenantBalance: tenantBalance ?? this.tenantBalance,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, buildings, rooms, tenants, payments, beds, tenantBalance];
}

// Deprecated states retained temporarily if needed, but we will migrate away.
// Actually, I will remove them to force migration and fix all errors.
