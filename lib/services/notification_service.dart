import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/policy_item.dart';

/// Schedules local (on-device) reminders for a scrapped policy's application
/// deadline at D-7/D-3/D-1. Deliberately local-only, not push/Firebase — the
/// deadline is already known the moment a policy is scrapped, so there's
/// nothing a server needs to decide later, and this avoids standing up any
/// backend/Firebase infrastructure just for this.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _daysBeforeDeadline = [7, 3, 1];
  static const _reminderHour = 9; // 오전 9시에 알림

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialization (and every plugin call below) is wrapped defensively —
  /// no platform channel host (unsupported platform, plugin missing in
  /// tests, permission denied) should ever be able to break the surrounding
  /// scrap/unscrap flow. Worst case, the user just doesn't get a reminder.
  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      // 온통청년 정책은 한국 정책이라 사용자도 한국 시간대라고 가정한다.
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _initialized = true;
    } catch (_) {
      // 무시 — 위 설명 참고.
    }
  }

  /// [policy]를 식별하는 policyNo(없으면 이름)로부터 D-7/D-3/D-1용 알림 id 3개를
  /// 만든다. 스크랩할 때 예약한 id와 스크랩 해제할 때 취소하는 id가 같은 정책에
  /// 대해 항상 똑같이 계산돼야 하므로, 정책 자체가 아니라 이 식별자만 이용한다.
  List<int> _notificationIds(PolicyItem policy) {
    final key = policy.policyNo ?? policy.name;
    final base = (key.hashCode & 0x7fffffff) ~/ 10 * 10;
    return [for (var i = 0; i < _daysBeforeDeadline.length; i++) base + i];
  }

  Future<void> scheduleDeadlineReminders(PolicyItem policy) async {
    final deadline = policy.deadline;
    if (deadline == null) return;
    await init();
    if (!_initialized) return;

    try {
      final ids = _notificationIds(policy);
      final now = tz.TZDateTime.now(tz.local);

      for (var i = 0; i < _daysBeforeDeadline.length; i++) {
        final daysBefore = _daysBeforeDeadline[i];
        final fireDate = tz.TZDateTime(
          tz.local,
          deadline.year,
          deadline.month,
          deadline.day - daysBefore,
          _reminderHour,
        );
        // 이미 지난 시점(예: 마감 3일 전에서야 스크랩한 경우 D-7 알림)은 예약하지 않는다.
        if (!fireDate.isAfter(now)) continue;

        await _plugin.zonedSchedule(
          id: ids[i],
          title: '정책 마감이 얼마 안 남았어요',
          body: '"${policy.name}" 신청 마감이 $daysBefore일 남았어요.',
          scheduledDate: fireDate,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'policy_deadline',
              '정책 마감 알림',
              channelDescription: '스크랩한 정책의 신청 마감이 다가올 때 알려드려요.',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // 무시 — [init] 설명 참고.
    }
  }

  Future<void> cancelDeadlineReminders(PolicyItem policy) async {
    try {
      for (final id in _notificationIds(policy)) {
        await _plugin.cancel(id: id);
      }
    } catch (_) {
      // 무시 — [init] 설명 참고.
    }
  }

  /// 실제 마감 D-7/D-3/D-1까지 기다리지 않고, 알림 권한 요청부터 실제 시스템
  /// 알림 표시까지 전체 경로가 동작하는지 바로 확인해보기 위한 디버그 전용
  /// 헬퍼. 프로필 화면의 디버그 빌드 전용 버튼에서만 호출된다.
  Future<void> scheduleTestNotification() async {
    await init();
    if (!_initialized) return;

    try {
      await _plugin.zonedSchedule(
        id: 999999999,
        title: '테스트 알림',
        body: '10초 뒤 알림이 정상적으로 왔다면 예약 기능이 잘 동작하는 거예요.',
        scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'policy_deadline',
            '정책 마감 알림',
            channelDescription: '스크랩한 정책의 신청 마감이 다가올 때 알려드려요.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // 무시 — [init] 설명 참고.
    }
  }
}
