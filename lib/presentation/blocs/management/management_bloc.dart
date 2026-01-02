import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/building_model.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/tenant_model.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/models/bed_model.dart';
import '../../../data/repositories/management_repository.dart';

part 'management_event.dart';
part 'management_state.dart';

class ManagementBloc extends Bloc<ManagementEvent, ManagementState> {
  final ManagementRepository _repository;

  ManagementBloc({
    required ManagementRepository repository,
  })  : _repository = repository,
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
    on<CheckoutTenant>(_onCheckoutTenant);
    
    on<LoadPayments>(_onLoadPayments);
    on<AddPayment>(_onAddPayment);
    on<DeletePayment>(_onDeletePayment);
    
    on<LoadTenantBalance>(_onLoadTenantBalance);
    on<TriggerManualSync>(_onTriggerManualSync);
  }

  Future<void> _onCheckoutTenant(
    CheckoutTenant event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      // 1. Mark tenant inactive
      final inactiveTenant = event.tenant.copyWith(active: false);
      await _repository.updateTenant(inactiveTenant);
      
      // 2. Mark bed as vacant
      await _repository.updateBedStatus(event.tenant.bedId, BedStatus.vacant);
      
      // The stream in repository will automatically notify UI of these changes
      emit(_currentState.copyWith(isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  ManagementLoaded get _currentState {
    if (state is ManagementLoaded) {
      return state as ManagementLoaded;
    }
    return const ManagementLoaded();
  }

  // --- Load All (Startup Optimization with Local Sync) ---

  Future<void> _onLoadAllManagementData(
    LoadAllManagementData event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    
    // Use the stream from repository for local-first loading
    await emit.forEach<Map<String, dynamic>>(
      _repository.getAllDataStream(),
      onData: (data) {
        return _currentState.copyWith(
          buildings: data['buildings'] as List<BuildingModel>,
          rooms: data['rooms'] as List<RoomModel>,
          tenants: data['tenants'] as List<TenantModel>,
          payments: data['payments'] as List<PaymentModel>,
          beds: data['beds'] as List<BedModel>,
          isLoading: false, // Serve instantly, don't keep loading state if we have local data
        );
      },
      onError: (error, stackTrace) {
        return _currentState.copyWith(error: error.toString(), isLoading: false);
      },
    );
  }

  // --- Buildings ---

  Future<void> _onLoadBuildings(
    LoadBuildings event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      await _repository.triggerSync(); // Try to sync pending changes first
      final buildings = await _repository.getBuildings();
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
      await _repository.addBuilding(event.building);
      // No need to manually fetch or emit here, the stream handles it
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
      await _repository.updateBuilding(event.building);
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
      await _repository.deleteBuilding(event.buildingId);
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
      await _repository.triggerSync();
      final rooms = await _repository.getRooms();
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
      await _repository.addRoom(event.room);
      // Background: get rooms to ensure we have the generated ID for bed creation
      // Actually, my repository handles sync internally now.
      // For immediate bed creation, we might still need the ID if it's local-first.
      // But repo.addRoom returns nothing. 
      // I'll keep the logic but rely on repository to be consistent.
      
      final rooms = await _repository.getRooms();
      final createdRoom = rooms.firstWhere(
        (r) => r.roomNumber == event.room.roomNumber && r.buildingId == event.room.buildingId,
        orElse: () => event.room,
      );
      
      if (createdRoom.roomId != null && createdRoom.roomId!.isNotEmpty) {
        for (int i = 0; i < event.room.lowerBedsCount; i++) {
          await _repository.addBed(BedModel(
            roomId: createdRoom.roomId!,
            bedType: BedType.lower,
            status: BedStatus.vacant,
          ));
        }
        for (int i = 0; i < event.room.upperBedsCount; i++) {
          await _repository.addBed(BedModel(
            roomId: createdRoom.roomId!,
            bedType: BedType.upper,
            status: BedStatus.vacant,
          ));
        }
      }
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
      await _repository.updateRoom(event.room);
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
      await _repository.deleteRoom(event.roomId);
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
      await _repository.triggerSync();
      final tenants = await _repository.getTenants();
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
      await _repository.addTenant(event.tenant);
      await _repository.updateBedStatus(event.tenant.bedId, BedStatus.occupied);
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
      final oldTenant = await _repository.getTenantById(event.tenant.tenantId!);
      if (oldTenant != null && oldTenant.bedId != event.tenant.bedId) {
        await _repository.updateBedStatus(oldTenant.bedId, BedStatus.vacant);
        await _repository.updateBedStatus(event.tenant.bedId, BedStatus.occupied);
      }
      await _repository.updateTenant(event.tenant);
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
      final tenant = await _repository.getTenantById(event.tenantId);
      if (tenant != null) {
        await _repository.updateBedStatus(tenant.bedId, BedStatus.vacant);
      }
      await _repository.deleteTenant(event.tenantId);
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
      await _repository.triggerSync();
      final payments = await _repository.getPayments();
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
      await _repository.addPayment(event.payment);
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
      await _repository.deletePayment(event.paymentId);
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
      final balance = await _repository.getTenantRentBalance(event.tenantId);
      emit(_currentState.copyWith(tenantBalance: balance, isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> _onTriggerManualSync(
    TriggerManualSync event,
    Emitter<ManagementState> emit,
  ) async {
    emit(_currentState.copyWith(isLoading: true));
    try {
      await _repository.triggerSync();
      emit(_currentState.copyWith(isLoading: false));
    } catch (e) {
      emit(_currentState.copyWith(error: e.toString(), isLoading: false));
    }
  }
}
