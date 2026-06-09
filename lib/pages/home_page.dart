import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/salawat_service.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  bool isRunning = false;
  int selectedMinutes = 5;
  final service = FlutterBackgroundService();
  final List<int> intervals = [1, 2, 5, 10, 15, 30, 60];
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _loadState();
    _requestBatteryOptimization();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final running = prefs.getBool('running') ?? false;
    setState(() {
      isRunning = running;
      selectedMinutes = prefs.getInt('interval') ?? 5;
    });
  }

  static const _batteryChannel = MethodChannel('com.example.salawat_app/battery');

  Future<void> _requestBatteryOptimization() async {
    try {
      final isIgnoring = await _batteryChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
      if (!isIgnoring) {
        await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    } catch (e) {
      debugPrint('Error checking/requesting battery optimization: $e');
    }
  }


  void toggleService() async {
    final prefs = await SharedPreferences.getInstance();
    final newRunning = !isRunning;
    await prefs.setBool('running', newRunning);
    await updateServiceState();
    setState(() => isRunning = newRunning);
  }

  void changeInterval(int min) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => selectedMinutes = min);
    await prefs.setInt('interval', min);
    // The background service picks up the new interval automatically via prefs.reload()
    // No need to restart or touch the running state
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isRunning
                ? [const Color(0xFF0D2B0D), const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                : [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header
                  Text(
                    'اللهم صلِّ وسلم على سيدنا محمد',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isRunning ? Colors.white : const Color(0xFF1B5E20),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'وعلى آله وصحبه أجمعين',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 14,
                      color: isRunning ? Colors.white70 : const Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Animated mosque icon
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isRunning ? _pulseAnim.value : 1.0,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: isRunning
                              ? [const Color(0xFF4CAF50), const Color(0xFF1B5E20)]
                              : [const Color(0xFFA5D6A7), const Color(0xFF66BB6A)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isRunning
                                ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.1),
                            blurRadius: isRunning ? 30 : 10,
                            spreadRadius: isRunning ? 5 : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.mosque_rounded,
                        size: 65,
                        color: isRunning ? const Color(0xFFFFD54F) : Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Status badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isRunning
                          ? const Color(0xFFFFD54F).withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isRunning ? const Color(0xFFFFD54F) : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isRunning ? const Color(0xFFFFD54F) : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isRunning ? 'يعمل — كل $selectedMinutes دقيقة' : 'متوقف',
                          style: TextStyle(
                            fontSize: 14,
                            color: isRunning ? const Color(0xFFFFD54F) : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Interval label
                  Text(
                    'المدة بين كل صلاة',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 14,
                      color: isRunning ? Colors.white70 : const Color(0xFF555555),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Interval selector
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: intervals.map((min) {
                      final selected = selectedMinutes == min;
                      return GestureDetector(
                        onTap: () => changeInterval(min),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFFD54F)
                                : (isRunning
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFE8F5E9)),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFFFD54F)
                                  : (isRunning
                                      ? Colors.white24
                                      : const Color(0xFFA5D6A7)),
                            ),
                          ),
                          child: Text(
                            min == 60 ? 'ساعة' : '$min د',
                            style: TextStyle(
                              color: selected
                                  ? Colors.black87
                                  : (isRunning ? Colors.white70 : const Color(0xFF2E7D32)),
                              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 40),

                  // Toggle Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: toggleService,
                      icon: Icon(
                        isRunning ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                        size: 24,
                      ),
                      label: Text(
                        isRunning ? 'إيقاف الصلاة على النبي' : 'تشغيل الصلاة على النبي',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRunning
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: isRunning ? 4 : 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
