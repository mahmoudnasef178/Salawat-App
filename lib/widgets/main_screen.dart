import 'package:flutter/material.dart';
import '../pages/home_page.dart';
import '../pages/azkar/azkar_page.dart';
import '../pages/quran/quran_page.dart';
import '../pages/prayer_times_page.dart';
import 'bottom_nav_bar.dart';

/// الشاشة الرئيسية التي تحتوي على التنقل بين الصفحات الأربع
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    HomePage(),
    AzkarPage(),
    QuranPage(),
    PrayerTimesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
