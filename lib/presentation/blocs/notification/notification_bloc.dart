import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../data/models/tenant_model.dart';
import '../../../data/repositories/management_repository.dart';

part 'notification_event.dart';
part 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final ManagementRepository? _repository;

  NotificationBloc({ManagementRepository? repository})
      : _repository = repository,
        super(NotificationInitial()) {
    on<NotificationInitializeRequested>(_onNotificationInitializeRequested);
    on<NotificationScheduleRemindersRequested>(
        _onNotificationScheduleRemindersRequested);
  }

  Future<void> _onNotificationInitializeRequested(
    NotificationInitializeRequested event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {},
      );

      emit(NotificationInitialized());
    } catch (e) {
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> _onNotificationScheduleRemindersRequested(
    NotificationScheduleRemindersRequested event,
    Emitter<NotificationState> emit,
  ) async {
    if (_repository == null) {
      emit(NotificationError('Repository not available'));
      return;
    }

    try {
      final tenants = await _repository!.getTenants();
      final activeTenants = tenants.where((t) => t.active).toList();

      final now = DateTime.now();
      int notificationId = 0;

      for (final tenant in activeTenants) {
        final dueDay = tenant.rentDueDay;
        final reminderDate = DateTime(now.year, now.month, dueDay)
            .subtract(const Duration(days: 3));

        // Only schedule if reminder is in the future
        if (reminderDate.isAfter(now)) {
          await _scheduleNotification(
            id: notificationId++,
            title: 'Rent Reminder',
            body:
                '${tenant.tenantName} - Room ${tenant.roomId} - Rent: ₹${tenant.rentAmount.toStringAsFixed(0)}',
            scheduledDate: reminderDate,
          );
        }
      }

      emit(NotificationRemindersScheduled());
    } catch (e) {
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rent_reminders',
          'Rent Reminders',
          channelDescription: 'Notifications for rent due reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
