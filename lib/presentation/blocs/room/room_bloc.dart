import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/building_model.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/bed_model.dart';
import '../../../data/models/tenant_model.dart';
import '../../../data/repositories/management_repository.dart';

part 'room_event.dart';
part 'room_state.dart';

class RoomBloc extends Bloc<RoomEvent, RoomState> {
  final ManagementRepository _repository;
  String? _selectedRoomId;

  // Cache for instant details calculation
  List<BedModel> _cachedBeds = [];
  List<TenantModel> _cachedTenants = [];

  RoomBloc({required ManagementRepository repository})
    : _repository = repository,
      super(const RoomInitial()) {
    on<RoomLoadRequested>(_onRoomLoadRequested);
    on<RoomDetailRequested>(_onRoomDetailRequested);
  }

  Future<void> _onRoomLoadRequested(
    RoomLoadRequested event,
    Emitter<RoomState> emit,
  ) async {
    if (state is! RoomsLoaded) {
      emit(const RoomLoading());
    }

    await emit.forEach<Map<String, dynamic>>(
      _repository.getAllDataStream(),
      onData: (data) {
        final buildings = data['buildings'] as List<BuildingModel>;
        final rooms = data['rooms'] as List<RoomModel>;
        final beds = data['beds'] as List<BedModel>;
        final tenants = data['tenants'] as List<TenantModel>;

        // Update cache
        _cachedBeds = beds;
        _cachedTenants = tenants;

        final Map<String, List<RoomWithStats>> roomsByBuilding = {};

        for (final building in buildings) {
          final buildingRooms = rooms
              .where((r) => r.buildingId == building.buildingId)
              .toList();
          final roomsWithStats = buildingRooms.map((room) {
            final roomBeds = beds
                .where((b) => b.roomId == room.roomId)
                .toList();
            final vacantLower = roomBeds
                .where(
                  (b) =>
                      b.bedType == BedType.lower &&
                      b.status == BedStatus.vacant,
                )
                .length;
            final vacantUpper = roomBeds
                .where(
                  (b) =>
                      b.bedType == BedType.upper &&
                      b.status == BedStatus.vacant,
                )
                .length;

            return RoomWithStats(
              room: room,
              vacantLowerBeds: vacantLower,
              vacantUpperBeds: vacantUpper,
            );
          }).toList();

          roomsWithStats.sort((a, b) {
            final aTotalVacant = a.vacantLowerBeds + a.vacantUpperBeds;
            final bTotalVacant = b.vacantLowerBeds + b.vacantUpperBeds;
            if (aTotalVacant > 0 && bTotalVacant == 0) return -1;
            if (aTotalVacant == 0 && bTotalVacant > 0) return 1;
            return 0;
          });

          if (building.buildingId != null) {
            roomsByBuilding[building.buildingId!] = roomsWithStats;
          }
        }

        List<BedDetail>? selectedRoomDetails;
        if (_selectedRoomId != null) {
          selectedRoomDetails = _calculateBedDetails(_selectedRoomId!);
        }

        return RoomsLoaded(
          buildings: buildings,
          roomsByBuilding: roomsByBuilding,
          selectedRoomDetails: selectedRoomDetails,
          isDetailsLoading: false,
        );
      },
      onError: (e, _) => RoomError(e.toString()),
    );
  }

  void _onRoomDetailRequested(
    RoomDetailRequested event,
    Emitter<RoomState> emit,
  ) {
    _selectedRoomId = event.roomId;

    if (state is RoomsLoaded) {
      final currentLoaded = state as RoomsLoaded;

      // Calculate immediately from cache for instant response
      final details = _calculateBedDetails(event.roomId);

      emit(
        currentLoaded.copyWith(
          selectedRoomDetails: details,
          isDetailsLoading:
              details == null, // Only show loading if we couldn't calculate yet
        ),
      );
    }
  }

  List<BedDetail>? _calculateBedDetails(String roomId) {
    if (_cachedBeds.isEmpty) return null;

    final roomBeds = _cachedBeds.where((b) => b.roomId == roomId).toList();
    if (roomBeds.isEmpty) return [];

    final roomTenants = _cachedTenants
        .where((t) => t.roomId == roomId)
        .toList();

    return roomBeds.map((bed) {
      final tenant = roomTenants.firstWhere(
        (t) => t.bedId == bed.bedId && t.active,
        orElse: () => TenantModel(
          tenantName: '',
          phone: '',
          buildingId: '',
          roomId: '',
          bedId: '',
          rentAmount: 0,
          advanceAmount: 0,
          joiningDate: DateTime.now(),
          rentDueDay: 1,
          active: false,
        ),
      );

      return BedDetail(
        bed: bed,
        tenantName: tenant.active ? tenant.tenantName : null,
      );
    }).toList();
  }
}

class RoomWithStats {
  final RoomModel room;
  final int vacantLowerBeds;
  final int vacantUpperBeds;

  RoomWithStats({
    required this.room,
    required this.vacantLowerBeds,
    required this.vacantUpperBeds,
  });
}

class BedDetail {
  final BedModel bed;
  final String? tenantName;

  BedDetail({required this.bed, this.tenantName});
}
