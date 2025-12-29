import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/models/building_model.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/tenant_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/models/bed_model.dart';

part 'management_event.dart';
part 'management_state.dart';

class ManagementBloc extends Bloc<ManagementEvent, ManagementState> {
  final GoogleSheetsService _sheetsService;

  ManagementBloc({
    required GoogleSheetsService sheetsService,
  })  : _sheetsService = sheetsService,
        super(ManagementInitial()) {
    on<LoadBuildings>(_onLoadBuildings);
    on<AddBuilding>(_onAddBuilding);
    on<UpdateBuilding>(_onUpdateBuilding);
    on<DeleteBuilding>(_onDeleteBuilding);
    
    on<LoadRooms>(_onLoadRooms);
    on<AddRoom>(_onAddRoom);
    on<UpdateRoom>(_onUpdateRoom);
    on<DeleteRoom>(_onDeleteRoom);
    
    on<LoadTenants>(_onLoadTenants);
    on<AddTenant>(_onAddTenant);
    on<UpdateTenant>(_onUpdateTenant);
    on<DeleteTenant>(_onDeleteTenant);
    
    on<LoadPayments>(_onLoadPayments);
    on<AddPayment>(_onAddPayment);
    on<DeletePayment>(_onDeletePayment);
    
    on<LoadTenantBalance>(_onLoadTenantBalance);
  }

  Future<void> _onLoadBuildings(
    LoadBuildings event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      final buildings = await _sheetsService.getBuildings();
      emit(BuildingsLoaded(buildings: buildings));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onAddBuilding(
    AddBuilding event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      await _sheetsService.addBuilding(event.building);
      final buildings = await _sheetsService.getBuildings();
      emit(BuildingsLoaded(buildings: buildings));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onUpdateBuilding(
    UpdateBuilding event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      await _sheetsService.updateBuilding(event.building);
      final buildings = await _sheetsService.getBuildings();
      emit(BuildingsLoaded(buildings: buildings));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onDeleteBuilding(
    DeleteBuilding event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      await _sheetsService.deleteBuilding(event.buildingId);
      final buildings = await _sheetsService.getBuildings();
      emit(BuildingsLoaded(buildings: buildings));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onLoadRooms(
    LoadRooms event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      final rooms = await _sheetsService.getRooms();
      emit(RoomsLoaded(rooms: rooms));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onAddRoom(
    AddRoom event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      await _sheetsService.addRoom(event.room);
      // Get the created room to get its ID
      final rooms = await _sheetsService.getRooms();
      final createdRoom = rooms.firstWhere(
        (r) => r.roomNumber == event.room.roomNumber && r.buildingId == event.room.buildingId,
        orElse: () => event.room,
      );
      
      // Create beds for the room
      if (createdRoom.roomId != null) {
        for (int i = 0; i < event.room.lowerBedsCount; i++) {
          await _sheetsService.addBed(BedModel(
            roomId: createdRoom.roomId!,
            bedType: BedType.lower,
            status: BedStatus.vacant,
          ));
        }
        for (int i = 0; i < event.room.upperBedsCount; i++) {
          await _sheetsService.addBed(BedModel(
            roomId: createdRoom.roomId!,
            bedType: BedType.upper,
            status: BedStatus.vacant,
          ));
        }
      }
      
      final updatedRooms = await _sheetsService.getRooms();
      emit(RoomsLoaded(rooms: updatedRooms));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onUpdateRoom(
    UpdateRoom event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      await _sheetsService.updateRoom(event.room);
      final rooms = await _sheetsService.getRooms();
      emit(RoomsLoaded(rooms: rooms));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onDeleteRoom(
    DeleteRoom event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      await _sheetsService.deleteRoom(event.roomId);
      final rooms = await _sheetsService.getRooms();
      emit(RoomsLoaded(rooms: rooms));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onLoadTenants(
    LoadTenants event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      final tenants = await _sheetsService.getTenants();
      emit(TenantsLoaded(tenants: tenants));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onAddTenant(
    AddTenant event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      await _sheetsService.addTenant(event.tenant);
      // Update bed status to occupied
      await _sheetsService.updateBedStatus(event.tenant.bedId, BedStatus.occupied);
      final tenants = await _sheetsService.getTenants();
      emit(TenantsLoaded(tenants: tenants));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onUpdateTenant(
    UpdateTenant event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      await _sheetsService.updateTenant(event.tenant);
      final tenants = await _sheetsService.getTenants();
      emit(TenantsLoaded(tenants: tenants));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onDeleteTenant(
    DeleteTenant event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      // Get tenant to find bed ID
      final tenant = await _sheetsService.getTenantById(event.tenantId);
      if (tenant != null) {
        // Mark bed as vacant
        await _sheetsService.updateBedStatus(tenant.bedId, BedStatus.vacant);
      }
      await _sheetsService.deleteTenant(event.tenantId);
      final tenants = await _sheetsService.getTenants();
      emit(TenantsLoaded(tenants: tenants));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onLoadPayments(
    LoadPayments event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      final payments = await _sheetsService.getPayments();
      emit(PaymentsLoaded(payments: payments));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onAddPayment(
    AddPayment event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      await _sheetsService.addPayment(event.payment);
      final payments = await _sheetsService.getPayments();
      emit(PaymentsLoaded(payments: payments));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onDeletePayment(
    DeletePayment event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      await _sheetsService.deletePayment(event.paymentId);
      final payments = await _sheetsService.getPayments();
      emit(PaymentsLoaded(payments: payments));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }

  Future<void> _onLoadTenantBalance(
    LoadTenantBalance event,
    Emitter<ManagementState> emit,
  ) async {
    emit(ManagementLoading());
    try {
      final balance = await _sheetsService.getTenantRentBalance(event.tenantId);
      emit(TenantBalanceLoaded(balance: balance));
    } catch (e) {
      emit(ManagementError(e.toString()));
    }
  }
}

