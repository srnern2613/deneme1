import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Ayarlar → Bildirimler bölümündeki "Günlük Hatırlatma" ve "Seri Kaybı
/// Uyarısı" anahtarlarının GERÇEK bildirim planlaması. Bu servisten önce
/// (profile_screen.dart'ta) sadece SharedPreferences'a yazılıyordu — artık
/// aynı tercihler burada gerçek, yerel (cihaz üstü, sunucu gerektirmeyen)
/// zamanlanmış bildirimlere dönüşüyor.
///
/// Notlar / bilinçli sınırlamalar:
/// - "Seri Kaybı Uyarısı" burada, günlük hatırlatmadan daha geç bir saatte
///   (21:30, sabit) tetiklenen İKİNCİ bir günlük bildirim olarak kuruldu.
///   Kullanıcının o gün gerçekten pratik yapıp yapmadığını arka planda
///   kontrol eden "akıllı" bir sistem DEĞİL — bunun için ayrı bir arka plan
///   görev/iş yöneticisi (WorkManager vb.) kurulumu gerekir; bu, bugünkü
///   kapsamın ötesinde. Şimdilik sabit saatli bir hatırlatma olarak
///   çalışıyor, ki bu da kullanıcının asıl istediği "seriyi kaybetmeden
///   önce uyarılmak" ihtiyacını karşılıyor.
/// - Cihaz yeniden başlatıldığında (reboot) Android, `AlarmManager` ile
///   kurulmuş bekleyen alarmları TEMİZLER. Bunları reboot sonrası otomatik
///   yeniden kurmak için ayrı bir BOOT_COMPLETED receiver'ı gerekir — bugün
///   eklenmedi. Pratikte uygulama her açılışta `rearmFromPrefs()` çağırdığı
///   için kullanıcı uygulamayı bir kez açtığında hatırlatmalar kendiliğinden
///   yeniden kurulur.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int _dailyReminderId = 9001;
  static const int _streakLossId = 9002;

  static const _channelId = 'ignis_reminders';
  static const _channelName = 'Hatırlatmalar';
  static const _channelDesc = 'Günlük pratik ve seri kaybı hatırlatmaları';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      try {
        final deviceTz = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(deviceTz));
      } catch (e) {
        debugPrint('Saat dilimi tespit edilemedi, UTC kullanılacak: $e');
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      // P0 (#15): iOS başlatma ayarları eksikti — DarwinInitializationSettings
      // verilmeden bu eklenti iOS'ta bildirim göstermek için gereken şekilde
      // kurulmuyor. İzinler burada DEĞİL, requestPermission() içinde açıkça
      // istendiği için (Android'deki akışla tutarlı, kullanıcıyı iki kez
      // izin diyaloğuyla karşılaşmasın diye) request*Permission burada false.
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
      await _plugin.initialize(initSettings);

      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.defaultImportance,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService.init hatası: $e');
    }
  }

  /// Android 13+ için çalışma zamanı bildirim izni ister. Daha eski Android
  /// sürümlerinde manifest izni yeterli olduğundan bu no-op döner.
  /// Kullanıcı reddederse false döner — çağıran taraf (profile_screen.dart)
  /// anahtarı geri kapatıp kullanıcıyı bilgilendirebilir.
  Future<bool> requestPermission() async {
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        return granted ?? true;
      }
      // P0 (#15): iOS'ta izin isteği eksikti — DarwinInitializationSettings
      // eklenince artık burada da açıkça isteniyor (Android akışıyla aynı
      // desende, tek bir yerden).
      // DÜZELTME: platform UYGULAMA sınıfının adı 'Darwin' ÖNEKLİ DEĞİL —
      // sadece BAŞLATMA AYARLARI (DarwinInitializationSettings) paylaşımlı;
      // izin isteme sınıfı iOS için hâlâ 'IOSFlutterLocalNotificationsPlugin'
      // (macOS için ayrı olarak 'MacOSFlutterLocalNotificationsPlugin').
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImpl != null) {
        final granted = await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
        return granted ?? true;
      }
      return true;
    } catch (e) {
      debugPrint('NotificationService.requestPermission hatası: $e');
      return false;
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> scheduleDailyReminder({required int hour, required int minute}) async {
    if (!_initialized) await init();
    try {
      await _plugin.zonedSchedule(
        _dailyReminderId,
        'Zindan seni bekliyor! 🐲',
        'Bugünkü kelime pratiğini henüz yapmadın. Birkaç dakikanı ayır, serini sürdür.',
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        // Bu projede kurulu flutter_local_notifications sürümünde bu
        // parametre hâlâ zorunlu (iOS eski API'sinden kalma). "absoluteTime"
        // = verdiğimiz saat zaten doğru, ekstra bir yorumlama yapma demek.
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService.scheduleDailyReminder hatası: $e');
    }
  }

  Future<void> cancelDailyReminder() async {
    try {
      await _plugin.cancel(_dailyReminderId);
    } catch (e) {
      debugPrint('NotificationService.cancelDailyReminder hatası: $e');
    }
  }

  Future<void> scheduleStreakLossAlert() async {
    if (!_initialized) await init();
    try {
      await _plugin.zonedSchedule(
        _streakLossId,
        'Serini kaybetmek üzeresin! 🔥',
        'Bugün henüz pratik yapmadın — gece yarısından önce bir tur atıp serini koru.',
        _nextInstanceOfTime(21, 30),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService.scheduleStreakLossAlert hatası: $e');
    }
  }

  Future<void> cancelStreakLossAlert() async {
    try {
      await _plugin.cancel(_streakLossId);
    } catch (e) {
      debugPrint('NotificationService.cancelStreakLossAlert hatası: $e');
    }
  }

  /// Uygulama her açılışında SharedPreferences'taki mevcut tercihlere göre
  /// bildirimleri yeniden kurar — hem reboot sonrası temizlenen alarmları
  /// telafi eder hem de tercihlerin her zaman senkron kalmasını sağlar.
  Future<void> rearmFromPrefs({
    required bool dailyReminderEnabled,
    required int reminderHour,
    required int reminderMinute,
    required bool streakLossAlertEnabled,
  }) async {
    if (!_initialized) await init();
    if (dailyReminderEnabled) {
      await scheduleDailyReminder(hour: reminderHour, minute: reminderMinute);
    } else {
      await cancelDailyReminder();
    }
    if (streakLossAlertEnabled) {
      await scheduleStreakLossAlert();
    } else {
      await cancelStreakLossAlert();
    }
  }
}
