import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran_library/quran_library.dart';
import '../../core/constants/app_colors.dart';
import 'quran_index_sheet.dart';


/// صفحة القرآن الكريم — عرض المصحف مع إمكانية القراءة بملء الشاشة
class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  bool _isFullScreen = false;


  void _showIndexBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuranIndexSheet(),
    );
  }

  @override
  void dispose() {
    // تأكد من استعادة أشرطة النظام عند الخروج من الصفحة
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_isFullScreen,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_isFullScreen) {
            _closeFullScreen();
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.quranBackground,
          body: Column(
            children: [
              _isFullScreen ? _buildMiniBar(context) : _buildAppBar(context),
              Expanded(child: _buildQuranBody(context)),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildAppBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkGreen, AppColors.mediumGreen],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 75,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // عنوان الصفحة
                const Row(
                  children: [
                    Icon(
                      Icons.auto_stories_outlined,
                      color: AppColors.gold,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'القرآن الكريم',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        Text(
                          'برواية حفص عن عاصم',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // أزرار التحكم
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _openFullScreen(context),
                      icon: const Icon(
                        Icons.fullscreen_rounded,
                        color: AppColors.gold,
                        size: 28,
                      ),
                      tooltip: 'قراءة بملء الشاشة',
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showIndexBottomSheet(context),
                      icon: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.darkGreen,
                        size: 18,
                      ),
                      label: const Text(
                        'الفهرس',
                        style: TextStyle(
                          color: AppColors.darkGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        elevation: 3,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBar(BuildContext context) {
    return Container(
      color: AppColors.darkGreen,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 55,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // زر الخروج من ملء الشاشة
                IconButton(
                  onPressed: _closeFullScreen,
                  icon: const Icon(
                    Icons.fullscreen_exit_rounded,
                    color: AppColors.gold,
                    size: 28,
                  ),
                  tooltip: 'إنهاء ملء الشاشة',
                ),

                // مؤشر الوضع
                const Text(
                  'وضع القراءة بملء الشاشة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),

                // زر الفهرس
                IconButton(
                  onPressed: () => _showIndexBottomSheet(context),
                  icon: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.gold,
                    size: 24,
                  ),
                  tooltip: 'الفهرس',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuranBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth == 0 || constraints.maxHeight == 0) {
          return const SizedBox.shrink();
        }
        return _buildQuranLibraryScreen(context);
      },
    );
  }


  Widget _buildQuranLibraryScreen(BuildContext context) {
    return QuranLibraryScreen(
      parentContext: context,
      withPageView: true,
      useDefaultAppBar: false,
      isShowAudioSlider: false,
      isDark: false,
      backgroundColor: AppColors.quranBackground,
      textColor: const Color(0xFF1C1C1C),
      ayahSelectedBackgroundColor:
          AppColors.primaryGreen.withValues(alpha: 0.15),
      ayahIconColor: AppColors.primaryGreen,
      basmalaStyle: BasmalaStyle(
        basmalaColor: AppColors.primaryGreen,
        basmalaFontSize: 22.0,
        verticalPadding: 4.0,
      ),
      topBottomQuranStyle: TopBottomQuranStyle.defaults(
        isDark: false,
        context: context,
      ).copyWith(
        hizbName: 'حزب',
        juzName: 'جزء',
        sajdaName: 'سجدة',
      ),
      topBarStyle: QuranTopBarStyle.defaults(
        isDark: false,
        context: context,
      ).copyWith(
        showAudioButton: false,
        showFontsButton: true,
        tabIndexLabel: 'الفهرس',
        tabBookmarksLabel: 'العلامات',
        tabSearchLabel: 'بحث',
      ),
      indexTabStyle: IndexTabStyle.defaults(
        isDark: false,
        context: context,
      ).copyWith(
        tabSurahsLabel: 'السور',
        tabJozzLabel: 'الأجزاء',
      ),
      searchTabStyle: SearchTabStyle.defaults(
        isDark: false,
        context: context,
      ).copyWith(
        searchHintText: 'ابحث في القرآن الكريم...',
      ),
      bookmarksTabStyle: BookmarksTabStyle.defaults(
        isDark: false,
        context: context,
      ).copyWith(
        emptyStateText: 'لا توجد علامات مرجعية بعد',
        greenGroupText: 'علامات خضراء',
        yellowGroupText: 'علامات صفراء',
        redGroupText: 'علامات حمراء',
      ),
      ayahMenuStyle: AyahMenuStyle.defaults(
        isDark: false,
        context: context,
      ).copyWith(
        copySuccessMessage: 'تم نسخ الآية',
        showPlayAllButton: false,
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() {
      _isFullScreen = true;
    });
  }

  void _closeFullScreen() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    setState(() {
      _isFullScreen = false;
    });
  }

}
