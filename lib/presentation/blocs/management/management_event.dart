part of 'management_bloc.dart';

abstract class ManagementEvent extends Equatable {
  const ManagementEvent();

  @override
  List<Object> get props => [];
}


// Load All Data (for startup optimization)
class LoadAllManagementData extends ManagementEvent {
  const LoadAllManagementData();
}

// Buildings
class LoadBuildings extends ManagementEvent {
  const LoadBuildings();
}

class AddBuilding extends ManagementEvent {
  final BuildingModel building;

  const AddBuilding(this.building);

  @override
  List<Object> get props => [building];
}

class UpdateBuilding extends ManagementEvent {
  final BuildingModel building;

  const UpdateBuilding(this.building);

  @override
  List<Object> get props => [building];
}

class DeleteBuilding extends ManagementEvent {
  final String buildingId;

  const DeleteBuilding(this.buildingId);

  @override
  List<Object> get props => [buildingId];
}

// Rooms
class LoadRooms extends ManagementEvent {
  const LoadRooms();
}

class AddRoom extends ManagementEvent {
  final RoomModel room;

  const AddRoom(this.room);

  @override
  List<Object> get props => [room];
}

class UpdateRoom extends ManagementEvent {
  final RoomModel room;

  const UpdateRoom(this.room);

  @override
  List<Object> get props => [room];
}

class DeleteRoom extends ManagementEvent {
  final String roomId;

  const DeleteRoom(this.roomId);

  @override
  List<Object> get props => [roomId];
}

// Tenants
class LoadTenants extends ManagementEvent {
  const LoadTenants();
}

class AddTenant extends ManagementEvent {
  final TenantModel tenant;

  const AddTenant(this.tenant);

  @override
  List<Object> get props => [tenant];
}

class UpdateTenant extends ManagementEvent {
  final TenantModel tenant;

  const UpdateTenant(this.tenant);

  @override
  List<Object> get props => [tenant];
}

class DeleteTenant extends ManagementEvent {
  final String tenantId;

  const DeleteTenant(this.tenantId);

  @override
  List<Object> get props => [tenantId];
}

// Payments
class LoadPayments extends ManagementEvent {
  const LoadPayments();
}

class AddPayment extends ManagementEvent {
  final PaymentModel payment;

  const AddPayment(this.payment);

  @override
  List<Object> get props => [payment];
}

class DeletePayment extends ManagementEvent {
  final String paymentId;

  const DeletePayment(this.paymentId);

  @override
  List<Object> get props => [paymentId];
}

// Balance
class LoadTenantBalance extends ManagementEvent {
  final String tenantId;

  const LoadTenantBalance(this.tenantId);

  @override
  List<Object> get props => [tenantId];
}

