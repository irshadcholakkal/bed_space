part of 'room_bloc.dart';

abstract class RoomState extends Equatable {
  final List<BuildingModel> buildings;
  final Map<String, List<RoomWithStats>> roomsByBuilding;

  const RoomState({this.buildings = const [], this.roomsByBuilding = const {}});

  @override
  List<Object?> get props => [buildings, roomsByBuilding];
}

class RoomInitial extends RoomState {
  const RoomInitial() : super();
}

class RoomLoading extends RoomState {
  const RoomLoading() : super();
}

class RoomsLoaded extends RoomState {
  final List<BedDetail>? selectedRoomDetails;
  final bool isDetailsLoading;
  final String? error;

  const RoomsLoaded({
    super.buildings = const [],
    super.roomsByBuilding = const {},
    this.selectedRoomDetails,
    this.isDetailsLoading = false,
    this.error,
  });

  RoomsLoaded copyWith({
    List<BuildingModel>? buildings,
    Map<String, List<RoomWithStats>>? roomsByBuilding,
    List<BedDetail>? selectedRoomDetails,
    bool? isDetailsLoading,
    String? error,
  }) {
    return RoomsLoaded(
      buildings: buildings ?? this.buildings,
      roomsByBuilding: roomsByBuilding ?? this.roomsByBuilding,
      selectedRoomDetails: selectedRoomDetails ?? this.selectedRoomDetails,
      isDetailsLoading: isDetailsLoading ?? this.isDetailsLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    selectedRoomDetails,
    isDetailsLoading,
    error,
  ];
}

class RoomError extends RoomState {
  final String message;
  const RoomError(this.message) : super();

  @override
  List<Object?> get props => [...super.props, message];
}
