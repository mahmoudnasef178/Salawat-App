import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quran_library/quran_library.dart';
import 'core/constants/app_colors.dart';
import 'services/salawat_service.dart';
import 'widgets/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await notificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  try {
    await updateServiceState();
  } catch (e) {
    debugPrint('Error updating service state on main: $e');
  }

  await QuranLibrary.init();

  runApp(const SalawatApp());
}

class SalawatApp extends StatelessWidget {
  const SalawatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'روضة النور',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
        ),
        useMaterial3: false,
      ),
      home: const MainScreen(),
    );
  }
}
