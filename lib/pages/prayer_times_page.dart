import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/arabic_utils.dart';
import '../services/salawat_service.dart';

class PrayerTimesPage extends StatefulWidget {
  const PrayerTimesPage({super.key});

  @override
  State<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  Map<String, String>? _timings;
  Map<String, dynamic>? _dateInfo;
  String _locationName = '';
  bool _loading = true;
  String? _error;
  Timer? _ticker;
  DateTime _now = DateTime.now();

  // Only the 5 obligatory prayers in order
  static const List<String> _prayerKeys = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  static const Map<String, String> _prayerAr = {
    'Fajr': 'الفجر',
    'Dhuhr': 'الظهر',
    'Asr': 'العصر',
    'Maghrib': 'المغرب',
    'Isha': 'العشاء',
  };

  static const Map<String, IconData> _prayerIcons = {
    'Fajr': Icons.nights_stay_rounded,
    'Dhuhr': Icons.wb_sunny_rounded,
    'Asr': Icons.wb_cloudy_rounded,
    'Maghrib': Icons.wb_twilight_rounded,
    'Isha': Icons.bedtime_rounded,
  };

  bool _prayerNotificationEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
    _loadPrayerTimes();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _loadNotificationSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _prayerNotificationEnabled = prefs.getBool('prayer_notification_enabled') ?? false;
      });
    } catch (e) {
      debugPrint('Error loading notification setting: $e');
    }
  }

  void _togglePrayerNotification(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _prayerNotificationEnabled = value;
      });
      await prefs.setBool('prayer_notification_enabled', value);
      
      if (_timings != null) {
        await prefs.setString('prayer_timings', jsonEncode(_timings));
        final nowObj = DateTime.now();
        final todayStr = "${nowObj.year}-${nowObj.month.toString().padLeft(2, '0')}-${nowObj.day.toString().padLeft(2, '0')}";
        await prefs.setString('prayer_timings_date', todayStr);
      }
      
      await updateServiceState();
    } catch (e) {
      debugPrint('Error toggling prayer notification: $e');
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadPrayerTimes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Check & request location permission
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _error = perm == LocationPermission.deniedForever
              ? 'تم رفض إذن الموقع بشكل دائم.\nيرجى تفعيله من إعدادات التطبيق.'
              : 'يحتاج التطبيق إذن الوصول للموقع\nلتحديد مواقيت الصلاة.';
          _loading = false;
        });
        return;
      }

      // 2. Get position
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // 3. Fetch prayer times (method 5 = Egyptian General Authority)
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final url =
          'https://api.aladhan.com/v1/timings/$ts'
          '?latitude=${pos.latitude.toStringAsFixed(4)}'
          '&longitude=${pos.longitude.toStringAsFixed(4)}'
          '&method=5';

      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final timings =
            Map<String, String>.from(body['data']['timings'] as Map);
        final meta = body['data']['meta'] as Map<String, dynamic>;

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('prayer_latitude', pos.latitude);
          await prefs.setDouble('prayer_longitude', pos.longitude);
          await prefs.setString('prayer_timings', jsonEncode(timings));
          final nowObj = DateTime.now();
          final todayStr = "${nowObj.year}-${nowObj.month.toString().padLeft(2, '0')}-${nowObj.day.toString().padLeft(2, '0')}";
          await prefs.setString('prayer_timings_date', todayStr);
          await updateServiceState();
        } catch (e) {
          debugPrint('Error caching prayer times: $e');
        }

        setState(() {
          _timings = timings;
          _dateInfo = body['data']['date'] as Map<String, dynamic>;
          _locationName =
              '${meta['timezone'] ?? ''}'.replaceAll('_', ' ');
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'فشل تحميل المواقيت (${res.statusCode})';
          _loading = false;
        });
      }
    } on TimeoutException {
      setState(() {
        _error = 'انتهت مهلة الاتصال — تحقق من الإنترنت';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ: ${e.toString()}';
        _loading = false;
      });
    }
  }

  /// Returns the key of the next prayer, or null if all passed today
  String? get _nextPrayerKey {
    if (_timings == null) return null;
    for (final key in _prayerKeys) {
      final t = _prayerDateTime(key);
      if (t != null && _now.isBefore(t)) return key;
    }
    return _prayerKeys.first; // wrap to Fajr of tomorrow
  }

  DateTime? _prayerDateTime(String key) {
    final raw = _timings?[key];
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    return DateTime(
      _now.year,
      _now.month,
      _now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  Duration _durationUntil(String key) {
    var t = _prayerDateTime(key);
    if (t == null) return Duration.zero;
    if (_now.isAfter(t)) t = t.add(const Duration(days: 1));
    return t.difference(_now);
  }

  String _fmtCountdown(Duration d) => ArabicUtils.fmtCountdown(d);

  /// تحويل "HH:mm" (24 ساعة) إلى "H:mm ص/م"
  String _fmt12(String raw) => ArabicUtils.fmt12Hour(raw);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
            colors: [
              Color(0xFF061206),
              Color(0xFF0D2B0D),
              Color(0xFF1B5E20),
            ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? _buildLoader()
              : _error != null
                  ? _buildError()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFFFD54F)),
          SizedBox(height: 20),
          Text(
            'جاري تحديد موقعك...',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: Colors.white54,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _error!,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _loadPrayerTimes,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD54F),
                foregroundColor: Colors.black87,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final next = _nextPrayerKey;

    return RefreshIndicator(
      onRefresh: _loadPrayerTimes,
      color: const Color(0xFFFFD54F),
      backgroundColor: const Color(0xFF1B5E20),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(next)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildCard(_prayerKeys[i], next),
                childCount: _prayerKeys.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String? next) {
    final hijri = _dateInfo?['hijri'];
    final gregorian = _dateInfo?['readable'] ?? '';
    final hijriDay = hijri?['day'] ?? '';
    final hijriMonthAr = hijri?['month']?['ar'] ?? '';
    final hijriYear = hijri?['year'] ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        children: [
          // App title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time_rounded,
                  color: Color(0xFFFFD54F), size: 18),
              const SizedBox(width: 8),
              const Text(
                'مواقيت الصلاة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Location
          if (_locationName.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Colors.white38, size: 13),
                const SizedBox(width: 4),
                Text(
                  _locationName,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          const SizedBox(height: 4),

          // Dates
          Text(
            '$hijriDay $hijriMonthAr $hijriYear هـ',
            textDirection: TextDirection.rtl,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          Text(
            gregorian,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Next prayer countdown card
          if (next != null) ...[
            _buildCountdownCard(next),
            const SizedBox(height: 12),
            _buildNotificationToggleCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationToggleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFFFFD54F),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        'إشعار ثابت بالصلاة القادمة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'عرض الوقت المتبقي في شريط الإشعارات',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _prayerNotificationEnabled,
            activeColor: const Color(0xFFFFD54F),
            activeTrackColor: const Color(0xFFFFD54F).withOpacity(0.4),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white12,
            onChanged: _togglePrayerNotification,
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCard(String next) {
    final dur = _durationUntil(next);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          const Text(
            'الصلاة القادمة',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            _prayerAr[next]!,
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _fmt12(_timings![next]!),
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 14),
          // Countdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFFD54F).withOpacity(0.3)),
            ),
            child: Text(
              _fmtCountdown(dur),
              style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 36,
                fontWeight: FontWeight.w300,
                letterSpacing: 6,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'الوقت المتبقي',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String key, String? nextKey) {
    final isNext = key == nextKey;
    final time12 = _fmt12(_timings![key] ?? '--:--');
    final isPassed = () {
      final t = _prayerDateTime(key);
      return t != null && _now.isAfter(t);
    }();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isNext
            ? const Color(0xFFFFD54F)
            : isPassed
                ? Colors.white.withOpacity(0.04)
                : Colors.white.withOpacity(0.09),
        border: Border.all(
          color: isNext
              ? Colors.transparent
              : Colors.white.withOpacity(0.08),
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD54F).withOpacity(0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isNext
                  ? Colors.black.withOpacity(0.1)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _prayerIcons[key]!,
              color: isNext ? Colors.black87 : Colors.white60,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          // Name
          Expanded(
            child: Text(
              _prayerAr[key]!,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: isNext ? Colors.black87 : (isPassed ? Colors.white38 : Colors.white),
                fontSize: 18,
                fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          // Status badge for passed
          if (isPassed && !isNext)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'مضت',
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ),
          // Time
          Text(
            time12,
            style: TextStyle(
              color: isNext ? Colors.black87 : const Color(0xFFFFD54F),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
