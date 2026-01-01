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
    on<LoadAllManagementData>(_onLoadAllManagementData);
    
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

  ManagementLoaded get _currentState {
    if (state is ManagementLoaded) {
      return state as ManagementLoaded;
    }
    return const ManagementLoaded();
  }

  // --- Load All (Startup Optimization) ---

  Future<void> _onLoadAllManagementData(
    LoadAllManagementData event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      // Load all data in parallel
      final results = await Future.wait([
        _sheetsService.getBuildings(),
        _sheetsService.getRooms(),
        _sheetsService.getTenants(),
        _sheetsService.getPayments(),
      ]);
      
      emit(_currentState.copyWith(
        buildings: results[0] as List<BuildingModel>,
        rooms: results[1] as List<RoomModel>,
        tenants: results[2] as List<TenantModel>,
        payments: results[3] as List<PaymentModel>,
        isLoading: false,
      ));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  // --- Buildings ---

  Future<void> _onLoadBuildings(
    LoadBuildings event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      final buildings = await _sheetsService.getBuildings();
      emit(_currentState.copyWith(buildings: buildings, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onAddBuilding(
    AddBuilding event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      await _sheetsService.addBuilding(event.building);
      final buildings = await _sheetsService.getBuildings();
      emit(_currentState.copyWith(buildings: buildings, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onUpdateBuilding(
    UpdateBuilding event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      await _sheetsService.updateBuilding(event.building);
      final buildings = await _sheetsService.getBuildings();
      emit(_currentState.copyWith(buildings: buildings, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onDeleteBuilding(
    DeleteBuilding event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      await _sheetsService.deleteBuilding(event.buildingId);
      final buildings = await _sheetsService.getBuildings();
      emit(_currentState.copyWith(buildings: buildings, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  // --- Rooms ---

  Future<void> _onLoadRooms(
    LoadRooms event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      final rooms = await _sheetsService.getRooms();
      emit(_currentState.copyWith(rooms: rooms, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onAddRoom(
    AddRoom event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
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
      emit(_currentState.copyWith(rooms: updatedRooms, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onUpdateRoom(
    UpdateRoom event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      await _sheetsService.updateRoom(event.room);
      final rooms = await _sheetsService.getRooms();
      emit(_currentState.copyWith(rooms: rooms, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onDeleteRoom(
    DeleteRoom event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      await _sheetsService.deleteRoom(event.roomId);
      final rooms = await _sheetsService.getRooms();
      emit(_currentState.copyWith(rooms: rooms, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  // --- Tenants ---

  Future<void> _onLoadTenants(
    LoadTenants event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      final tenants = await _sheetsService.getTenants();
      emit(_currentState.copyWith(tenants: tenants, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onAddTenant(
    AddTenant event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      await _sheetsService.addTenant(event.tenant);
      // Update bed status to occupied
      await _sheetsService.updateBedStatus(event.tenant.bedId, BedStatus.occupied);
      final tenants = await _sheetsService.getTenants();
      // Also reload rooms to reflect any capacity/occupancy changes if computed
      // or at least we should reload tenants to get the new one.
      emit(_currentState.copyWith(tenants: tenants, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onUpdateTenant(
    UpdateTenant event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      // Get the current tenant to check if bed changed
      final oldTenant = await _sheetsService.getTenantById(event.tenant.tenantId!);
      
      // If bed changed, update bed statuses
      if (oldTenant != null && oldTenant.bedId != event.tenant.bedId) {
        // Mark old bed as vacant
        await _sheetsService.updateBedStatus(oldTenant.bedId, BedStatus.vacant);
        // Mark new bed as occupied
        await _sheetsService.updateBedStatus(event.tenant.bedId, BedStatus.occupied);
      }
      
      await _sheetsService.updateTenant(event.tenant);
      final tenants = await _sheetsService.getTenants();
      emit(_currentState.copyWith(tenants: tenants, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onDeleteTenant(
    DeleteTenant event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      // Get tenant to find bed ID
      final tenant = await _sheetsService.getTenantById(event.tenantId);
      if (tenant != null) {
        // Mark bed as vacant
        await _sheetsService.updateBedStatus(tenant.bedId, BedStatus.vacant);
      }
      await _sheetsService.deleteTenant(event.tenantId);
      final tenants = await _sheetsService.getTenants();
      emit(_currentState.copyWith(tenants: tenants, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  // --- Payments ---

  Future<void> _onLoadPayments(
    LoadPayments event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      final payments = await _sheetsService.getPayments();
      emit(_currentState.copyWith(payments: payments, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onAddPayment(
    AddPayment event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      await _sheetsService.addPayment(event.payment);
      final payments = await _sheetsService.getPayments();
      emit(_currentState.copyWith(payments: payments, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onDeletePayment(
    DeletePayment event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      await _sheetsService.deletePayment(event.paymentId);
      final payments = await _sheetsService.getPayments();
      emit(_currentState.copyWith(payments: payments, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onLoadTenantBalance(
    LoadTenantBalance event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      final balance = await _sheetsService.getTenantRentBalance(event.tenantId);
      emit(_currentState.copyWith(tenantBalance: balance, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }
}
