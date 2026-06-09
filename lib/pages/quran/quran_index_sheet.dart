import 'package:flutter/material.dart';
import 'package:quran_library/quran_library.dart' hide SurahModel;
import '../../core/constants/app_colors.dart';
import '../../core/utils/arabic_utils.dart';
import '../../models/surah_model.dart';

/// صفحة فهرس القرآن الكريم — تعرض فهرس السور وفهرس الصفحات
class QuranIndexSheet extends StatefulWidget {
  const QuranIndexSheet({super.key});

  @override
  State<QuranIndexSheet> createState() => _QuranIndexSheetState();
}

class _QuranIndexSheetState extends State<QuranIndexSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pageController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredSurahs = surahList.where((surah) {
      final nameMatches = surah.name.contains(_searchQuery);
      final numberMatches = surah.number.toString().contains(_searchQuery);
      return nameMatches || numberMatches;
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.quranIndexBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildDragHandle(),
            _buildSheetHeader(),
            _buildTabBar(),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSurahTab(filteredSurahs),
                  _buildPagesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 50,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSheetHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Icon(
            Icons.format_list_bulleted_rounded,
            color: AppColors.primaryGreen,
            size: 26,
          ),
          SizedBox(width: 10),
          Text(
            'فهرس القرآن الكريم',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGreen,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.primaryGreen,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            fontFamily: 'Cairo',
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            fontFamily: 'Cairo',
          ),
          tabs: const [
            Tab(text: 'فهرس السور'),
            Tab(text: 'فهرس الصفحات'),
          ],
        ),
      ),
    );
  }

  // ── تبويب السور ──────────────────────────────────────────────────────────────

  Widget _buildSurahTab(List<SurahModel> filteredSurahs) {
    return Column(
      children: [
        _buildSurahSearchBar(),
        Expanded(child: _buildSurahList(filteredSurahs)),
      ],
    );
  }

  Widget _buildSurahSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        decoration: InputDecoration(
          hintText: 'ابحث باسم السورة أو رقمها...',
          hintStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
            fontFamily: 'Cairo',
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.primaryGreen),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSurahList(List<SurahModel> filteredSurahs) {
    if (filteredSurahs.isEmpty) {
      return Center(
        child: Text(
          'لا توجد سورة تطابق البحث',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 14,
            fontFamily: 'Cairo',
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24, left: 12, right: 12),
      itemCount: filteredSurahs.length,
      itemBuilder: (context, index) {
        final surah = filteredSurahs[index];
        return Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: AppColors.backgroundGreen.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: ListTile(
            onTap: () {
              QuranLibrary().jumpToSurah(surah.number);
              Navigator.pop(context);
            },
            leading: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF9C4),
              ),
              child: Center(
                child: Text(
                  ArabicUtils.toArabicNum(surah.number),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8D6E63),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            title: Text(
              surah.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.darkGreen,
                fontFamily: 'Cairo',
              ),
            ),
            subtitle: Text(
              '${surah.type} • ${surah.verses} آيات',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontFamily: 'Cairo',
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'صفحة ${surah.page}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primaryGreen,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.black26,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── تبويب الصفحات ────────────────────────────────────────────────────────────

  Widget _buildPagesTab() {
    return Column(
      children: [
        _buildPageGoToRow(),
        Expanded(child: _buildPageGrid()),
      ],
    );
  }

  Widget _buildPageGoToRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _pageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'اكتب رقم الصفحة (1 - 604)...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontFamily: 'Cairo',
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _goToPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'انتقل',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToPage() {
    final text = _pageController.text.trim();
    if (text.isEmpty) return;

    final pNum = int.tryParse(text);
    if (pNum != null && pNum >= 1 && pNum <= 604) {
      QuranLibrary().jumpToPage(pNum);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى إدخال رقم صفحة صحيح بين 1 و 604',
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPageGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: 604,
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        return InkWell(
          onTap: () {
            QuranLibrary().jumpToPage(pageNumber);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.backgroundGreen,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ArabicUtils.toArabicNum(pageNumber),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ص $pageNumber',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade500,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
