part of 'room_bloc.dart';

abstract class RoomEvent extends Equatable {
  const RoomEvent();

  @override
  List<Object> get props => [];
}

class RoomLoadRequested extends RoomEvent {
  const RoomLoadRequested();
}

class RoomDetailRequested extends RoomEvent {
  final String roomId;

  const RoomDetailRequested(this.roomId);

  @override
  List<Object> get props => [roomId];
}

