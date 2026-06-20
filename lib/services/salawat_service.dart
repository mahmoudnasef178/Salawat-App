import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Initialize bindings for background Isolate to support native plugin usage (e.g. SharedPreferences)
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  bool salawatEnabled = false;
  bool prayerEnabled = false;
  bool azanEnabled = true;
  int intervalMinutes = 5;

  // Load initial settings
  try {
    final prefs = await SharedPreferences.getInstance();
    salawatEnabled = prefs.getBool('running') ?? false;
    prayerEnabled = prefs.getBool('prayer_notification_enabled') ?? false;
    azanEnabled = prefs.getBool('azan_sound_enabled') ?? true;
    intervalMinutes = prefs.getInt('interval') ?? 5;
  } catch (e) {
    debugPrint("Failed to load initial settings in background: $e");
  }

  // Update notification helper
  Future<void> updateNotification() async {
    if (!prayerEnabled) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "🤲 الصلاة على النبي",
          content: "التطبيق يعمل في الخلفية",
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final timingsJson = prefs.getString('prayer_timings');
    if (timingsJson == null) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "🕌 مواقيت الصلاة",
          content: "يرجى فتح التطبيق لتحديد الموقع وتحميل المواقيت",
        );
      }
      return;
    }

    try {
      Map<String, dynamic> timings = jsonDecode(timingsJson);
      final timingsDateStr = prefs.getString('prayer_timings_date');
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // If dates don't match, attempt to fetch fresh timings using saved coordinates
      if (timingsDateStr != todayStr) {
        final lat = prefs.getDouble('prayer_latitude');
        final lng = prefs.getDouble('prayer_longitude');
        if (lat != null && lng != null) {
          final ts = now.millisecondsSinceEpoch ~/ 1000;
          final url = 'https://api.aladhan.com/v1/timings/$ts?latitude=${lat.toStringAsFixed(4)}&longitude=${lng.toStringAsFixed(4)}&method=5';
          try {
            final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
            if (res.statusCode == 200) {
              final body = jsonDecode(res.body);
              final newTimings = Map<String, dynamic>.from(body['data']['timings'] as Map);
              await prefs.setString('prayer_timings', jsonEncode(newTimings));
              await prefs.setString('prayer_timings_date', todayStr);
              timings = newTimings;
            }
          } catch (e) {
            debugPrint("Failed to fetch prayer times in background: $e");
          }
        }
      }

      // Calculate next prayer
      const List<String> prayerKeys = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
      const Map<String, String> prayerAr = {
        'Fajr': 'الفجر',
        'Dhuhr': 'الظهر',
        'Asr': 'العصر',
        'Maghrib': 'المغرب',
        'Isha': 'العشاء',
      };

      String? nextKey;
      DateTime? nextTime;

      // Find next prayer for today
      for (final key in prayerKeys) {
        final rawTime = timings[key];
        if (rawTime != null) {
          final parts = rawTime.split(':');
          if (parts.length >= 2) {
            final t = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
            if (now.isBefore(t)) {
              nextKey = key;
              nextTime = t;
              break;
            }
          }
        }
      }

      // If all prayers passed today, wrap to Fajr of tomorrow
      if (nextKey == null) {
        nextKey = prayerKeys.first;
        final rawTime = timings[nextKey];
        if (rawTime != null) {
          final parts = rawTime.split(':');
          if (parts.length >= 2) {
            nextTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1])).add(const Duration(days: 1));
          }
        }
      }

      if (nextTime != null) {
        final rawTime = timings[nextKey] as String;
        
        // Format time in 12-hour format
        String formattedTime = rawTime;
        try {
          final p = rawTime.split(':');
          int h = int.parse(p[0]);
          final m = p[1];
          final suffix = h >= 12 ? 'م' : 'ص';
          if (h > 12) h -= 12;
          if (h == 0) h = 12;
          formattedTime = '$h:$m $suffix';
        } catch (_) {}

        final diff = nextTime.difference(now);
        final hr = diff.inHours;
        final mn = diff.inMinutes % 60;
        String pad(int n) => n.toString().padLeft(2, '0');
        
        // Formatted countdown: e.g. "01:25" or "45 دقيقة" (Only prayer times, no dhikr info)
        final remainingStr = hr > 0 ? '$hr:${pad(mn)}' : '$mn دقيقة';

        final title = "🕌 صلاة ${prayerAr[nextKey]} في $formattedTime";
        final content = "⏳ المتبقي: $remainingStr";

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: title,
            content: content,
          );
        }
      }
    } catch (e) {
      debugPrint("Error updating notification text: $e");
    }
  }

  service.on('updateSettings').listen((data) {
    if (data != null) {
      if (data['salawat_enabled'] != null) {
        salawatEnabled = data['salawat_enabled'] as bool;
      }
      if (data['prayer_enabled'] != null) {
        prayerEnabled = data['prayer_enabled'] as bool;
      }
      if (data['azan_enabled'] != null) {
        azanEnabled = data['azan_enabled'] as bool;
      }
      // Note: interval is handled by prefs.reload() in the periodic timer, not here
      updateNotification();
    }
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // Update immediately
  await updateNotification();

  // Notification update timer (every 60 seconds is enough and preserves battery)
  Timer.periodic(const Duration(seconds: 60), (timer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      prayerEnabled = prefs.getBool('prayer_notification_enabled') ?? false;
      salawatEnabled = prefs.getBool('running') ?? false;
      azanEnabled = prefs.getBool('azan_sound_enabled') ?? true;
    } catch (_) {}
    await updateNotification();
  });

  // Audio reminder check loop
  final player = AudioPlayer();
  bool isAzaanPlaying = false;
  player.onPlayerComplete.listen((event) {
    isAzaanPlaying = false;
  });

  // Start so that first play fires after one full interval, not immediately
  DateTime lastPlayTime = DateTime.now();
  // Track last known interval to detect changes from UI
  int lastKnownInterval = intervalMinutes;

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      salawatEnabled = prefs.getBool('running') ?? false;
      azanEnabled = prefs.getBool('azan_sound_enabled') ?? true;
      final newInterval = prefs.getInt('interval') ?? 5;

      // Only reset countdown when interval changes — don't touch lastPlayTime from updateSettings
      if (newInterval != lastKnownInterval) {
        lastKnownInterval = newInterval;
        intervalMinutes = newInterval;
        // Give the user the new interval from NOW (don't play immediately)
        lastPlayTime = DateTime.now();
      }

      // Check if it is a prayer time to play Azan
      if (azanEnabled) {
        final timingsJson = prefs.getString('prayer_timings');
        if (timingsJson != null) {
          final Map<String, dynamic> timings = jsonDecode(timingsJson);
          const List<String> prayerKeys = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
          final now = DateTime.now();

          for (final key in prayerKeys) {
            final rawTime = timings[key];
            if (rawTime != null) {
              final parts = rawTime.split(':');
              if (parts.length >= 2) {
                final hr = int.tryParse(parts[0]);
                final mn = int.tryParse(parts[1]);
                if (hr != null && mn != null) {
                  if (now.hour == hr && now.minute == mn) {
                    final todayPrayerId = "${now.year}-${now.month}-${now.day}_$key";
                    final lastPlayed = prefs.getString('last_played_prayer') ?? '';
                    if (lastPlayed != todayPrayerId) {
                      try {
                        isAzaanPlaying = true;
                        // Stop any current sound (like Salawat) and play Azan
                        await player.stop();
                        await player.play(AssetSource('azaan.mp3'));
                        await prefs.setString('last_played_prayer', todayPrayerId);
                      } catch (e) {
                        isAzaanPlaying = false;
                        debugPrint('Error playing Azan in background: $e');
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    if (salawatEnabled && !isAzaanPlaying) {
      final now = DateTime.now();
      final elapsed = now.difference(lastPlayTime).inSeconds;
      final thresholdSeconds = intervalMinutes * 60;
      if (elapsed >= thresholdSeconds) {
        try {
          // Stop any previous play before starting new one
          await player.stop();
          await player.play(AssetSource('salawat.mp3'));
          lastPlayTime = now;
        } catch (e) {
          debugPrint('Error playing audio in background: $e');
        }
      }
    }
  });
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'salawat_channel_silent',
    'خدمة الصلاة على النبي والمواقيت',
    description: 'تشغيل الخدمة في الخلفية للتذكير ومواقيت الصلاة',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(channel);
  
  // Request permission automatically on Android 13+
  await androidPlugin?.requestNotificationsPermission();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'salawat_channel_silent',
      initialNotificationTitle: '🕌 مواقيت الصلاة',
      initialNotificationContent: 'جاري تحديث البيانات...',
      foregroundServiceNotificationId: 888,
      autoStartOnBoot: false,
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

Future<void> updateServiceState() async {
  final prefs = await SharedPreferences.getInstance();
  final bool salawatEnabled = prefs.getBool('running') ?? false;
  final bool prayerEnabled = prefs.getBool('prayer_notification_enabled') ?? false;
  final bool azanEnabled = prefs.getBool('azan_sound_enabled') ?? true;

  final service = FlutterBackgroundService();
  final isRunning = await service.isRunning();

  if (salawatEnabled || prayerEnabled || azanEnabled) {
    if (!isRunning) {
      await initializeService();
      await service.startService();
    }
    // Update variables inside running service Isolate
    final selectedMinutes = prefs.getInt('interval') ?? 5;
    service.invoke('updateSettings', {
      'salawat_enabled': salawatEnabled,
      'prayer_enabled': prayerEnabled,
      'azan_enabled': azanEnabled,
      'interval': selectedMinutes,
    });
  } else {
    if (isRunning) {
      service.invoke('stopService');
    }
  }
}
