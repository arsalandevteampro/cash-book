import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/follow_up.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String _channelId = 'cash_book_follow_ups';
  static const String _channelName = 'Follow-ups & Reminders';
  static const String _channelDescription =
      'Notifications for scheduled payment follow-ups and due dates';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      if (Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        await androidImplementation?.requestNotificationsPermission();
        await androidImplementation?.requestExactAlarmsPermission();

        const channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );

        await androidImplementation?.createNotificationChannel(channel);
      }

      _isInitialized = true;
      if (kDebugMode) {
        print('✅ Local NotificationService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing NotificationService: $e');
      }
    }
  }

  int _getNotificationId(String followUpId) {
    return followUpId.hashCode.abs() % 2147483647;
  }

  Future<void> scheduleFollowUpNotification(FollowUp followUp) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Don't schedule if already completed
    if (followUp.isCompleted) {
      await cancelFollowUpNotification(followUp.id);
      return;
    }

    final now = DateTime.now();
    if (followUp.dueDate.isBefore(now)) {
      if (kDebugMode) {
        print('Follow-up due date is in the past, skipping future schedule');
      }
      return;
    }

    final id = _getNotificationId(followUp.id);
    final scheduledDate = tz.TZDateTime.from(followUp.dueDate, tz.local);

    final isReceive = followUp.type == FollowUpType.toReceive;
    final title = isReceive
        ? 'Reminder: Paisa Lena Hai (${followUp.contactName})'
        : 'Reminder: Paisa Dena Hai (${followUp.contactName})';

    final body = isReceive
        ? 'Rs ${followUp.amount.toStringAsFixed(0)} lena hai ${followUp.contactName} se. (${followUp.title})'
        : 'Rs ${followUp.amount.toStringAsFixed(0)} dena hai ${followUp.contactName} ko. (${followUp.title})';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: followUp.id,
      );

      if (kDebugMode) {
        print(
            '⏰ Scheduled notification for follow-up "${followUp.contactName}" at $scheduledDate (ID: $id)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling notification with exactAllowWhileIdle: $e. Retrying inexact...');
      }
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: followUp.id,
        );
      } catch (innerError) {
        if (kDebugMode) {
          print('Failed to schedule notification: $innerError');
        }
      }
    }
  }

  Future<void> cancelFollowUpNotification(String followUpId) async {
    try {
      final id = _getNotificationId(followUpId);
      await _notificationsPlugin.cancel(id);
      if (kDebugMode) {
        print('Cancelled notification for ID: $id');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling notification: $e');
      }
    }
  }

  Future<void> rescheduleAll(List<FollowUp> followUps) async {
    for (final followUp in followUps) {
      if (!followUp.isCompleted && followUp.dueDate.isAfter(DateTime.now())) {
        await scheduleFollowUpNotification(followUp);
      }
    }
  }
}
