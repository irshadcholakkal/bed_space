part of 'room_bloc.dart';

abstract class RoomState extends Equatable {
  const RoomState();

  @override
  List<Object> get props => [];
}

class RoomInitial extends RoomState {}

class RoomLoading extends RoomState {}

class RoomsLoaded extends RoomState {
  final List<BuildingModel> buildings;
  final Map<String, List<RoomWithStats>> roomsByBuilding;

  const RoomsLoaded({
    required this.buildings,
    required this.roomsByBuilding,
  });

  @override
  List<Object> get props => [buildings, roomsByBuilding];
}

class RoomDetailLoaded extends RoomState {
  final List<BedDetail> bedDetails;

  const RoomDetailLoaded({required this.bedDetails});

  @override
  List<Object> get props => [bedDetails];
}

class RoomError extends RoomState {
  final String message;

  const RoomError(this.message);

  @override
  List<Object> get props => [message];
}

