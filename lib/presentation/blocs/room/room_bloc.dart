import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/services/google_sheets_service.dart';
import '../../../data/models/building_model.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/bed_model.dart';
import '../../../data/models/tenant_model.dart';

part 'room_event.dart';
part 'room_state.dart';

class RoomBloc extends Bloc<RoomEvent, RoomState> {
  final GoogleSheetsService _sheetsService;

  RoomBloc({
    required GoogleSheetsService sheetsService,
  })  : _sheetsService = sheetsService,
        super(RoomInitial()) {
    on<RoomLoadRequested>(_onRoomLoadRequested);
    on<RoomDetailRequested>(_onRoomDetailRequested);
  }

  Future<void> _onRoomLoadRequested(
    RoomLoadRequested event,
    Emitter<RoomState> emit,
  ) async {
    emit(RoomLoading());
    try {
      final buildings = await _sheetsService.getBuildings();
      final rooms = await _sheetsService.getRooms();
      final beds = await _sheetsService.getBeds();

      // Group rooms by building and calculate vacancy
      final Map<String, List<RoomWithStats>> roomsByBuilding = {};

      for (final building in buildings) {
        final buildingRooms = rooms.where((r) => r.buildingId == building.buildingId).toList();
        final roomsWithStats = buildingRooms.map((room) {
          final roomBeds = beds.where((b) => b.roomId == room.roomId).toList();
          final vacantLower = roomBeds
              .where((b) => b.bedType == BedType.lower && b.status == BedStatus.vacant)
              .length;
          final vacantUpper = roomBeds
              .where((b) => b.bedType == BedType.upper && b.status == BedStatus.vacant)
              .length;

          return RoomWithStats(
            room: room,
            vacantLowerBeds: vacantLower,
            vacantUpperBeds: vacantUpper,
          );
        }).toList();

        // Sort: vacant rooms first
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

      emit(RoomsLoaded(
        buildings: buildings,
        roomsByBuilding: roomsByBuilding,
      ));
    } catch (e) {
      emit(RoomError(e.toString()));
    }
  }

  Future<void> _onRoomDetailRequested(
    RoomDetailRequested event,
    Emitter<RoomState> emit,
  ) async {
    emit(RoomLoading());
    try {
      final beds = await _sheetsService.getBeds();
      final tenants = await _sheetsService.getTenants();

      final roomBeds = beds.where((b) => b.roomId == event.roomId).toList();
      final roomTenants = tenants.where((t) => t.roomId == event.roomId).toList();

      final bedDetails = roomBeds.map((bed) {
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

      emit(RoomDetailLoaded(bedDetails: bedDetails));
    } catch (e) {
      emit(RoomError(e.toString()));
    }
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

  BedDetail({
    required this.bed,
    this.tenantName,
  });
}

