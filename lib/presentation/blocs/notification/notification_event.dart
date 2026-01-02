part of 'notification_bloc.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object> get props => [];
}

class NotificationInitializeRequested extends NotificationEvent {
  const NotificationInitializeRequested();
}

class NotificationScheduleRemindersRequested extends NotificationEvent {
  const NotificationScheduleRemindersRequested();
}
