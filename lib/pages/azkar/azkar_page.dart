import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/arabic_utils.dart';
import 'azkar_list_screen.dart';

/// صفحة الأذكار الرئيسية — تعرض الأذكار المميزة وباقي التصنيفات
class AzkarPage extends StatefulWidget {
  const AzkarPage({super.key});

  @override
  State<AzkarPage> createState() => _AzkarPageState();
}

class _AzkarPageState extends State<AzkarPage> {
  Map<String, List<Map<String, dynamic>>> _categories = {};
  Map<String, int> _completedCounts = {};
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// تعريف التصنيفات المميزة مع ألوانها وأيقوناتها
  final List<Map<String, dynamic>> _featuredCategoriesInfo = [
    {
      'name': 'أذكار الصباح',
      'icon': Icons.wb_sunny_rounded,
      'colors': [const Color(0xFFE57373), const Color(0xFFFFB74D)],
    },
    {
      'name': 'أذكار المساء',
      'icon': Icons.nightlight_round,
      'colors': [const Color(0xFF3F51B5), const Color(0xFF9C27B0)],
    },
    {
      'name': 'أذكار النوم',
      'icon': Icons.bedtime_rounded,
      'colors': [const Color(0xFF1A237E), const Color(0xFF3949AB)],
    },
    {
      'name': 'الأذكار بعد السلام من الصلاة',
      'icon': Icons.mosque_rounded,
      'colors': [const Color(0xFF004D40), const Color(0xFF00796B)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final String data = await rootBundle.loadString('assets/azkar.json');
      final List<dynamic> jsonList = jsonDecode(data);
      final prefs = await SharedPreferences.getInstance();

      final Map<String, List<Map<String, dynamic>>> tempCategories = {};
      final Map<String, int> tempCompleted = {};

      for (var item in jsonList) {
        final category = item['category']?.toString() ?? 'أخرى';
        final mapItem = Map<String, dynamic>.from(item);

        mapItem['count'] = ArabicUtils.parseCount(mapItem['count']);

        tempCategories.putIfAbsent(category, () => []).add(mapItem);

        final id = mapItem['id'].toString();
        final remaining =
            prefs.getInt('azkar_remaining_$id') ?? mapItem['count'] as int;

        if (remaining == 0) {
          tempCompleted[category] = (tempCompleted[category] ?? 0) + 1;
        }
      }

      setState(() {
        _categories = tempCategories;
        _completedCounts = tempCompleted;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading azkar data: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.azkarBackground,
        appBar: AppBar(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'الأذكار',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                ),
              )
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final filteredCategoryNames = _categories.keys.where((cat) {
      return cat.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        _buildSearchField(),
        Expanded(
          child: _searchQuery.isNotEmpty
              ? _buildSearchResults(filteredCategoryNames)
              : _buildMainDashboard(),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() => _searchQuery = val.trim());
          },
          decoration: InputDecoration(
            hintText: 'ابحث عن تصنيف الأذكار...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.primaryGreen),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(List<String> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد تصنيفات مطابقة لبحثك',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final categoryName = results[index];
        final items = _categories[categoryName] ?? [];
        final completed = _completedCounts[categoryName] ?? 0;
        return _buildCategoryListItem(categoryName, items.length, completed);
      },
    );
  }

  Widget _buildMainDashboard() {
    final featuredNames =
        _featuredCategoriesInfo.map((e) => e['name'] as String).toList();
    final otherCategoryNames =
        _categories.keys.where((cat) => !featuredNames.contains(cat)).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      children: [
        const Text(
          'أذكار رئيسية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.mediumGreen,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
          ),
          itemCount: _featuredCategoriesInfo.length,
          itemBuilder: (context, index) {
            final info = _featuredCategoriesInfo[index];
            final name = info['name'] as String;
            final icon = info['icon'] as IconData;
            final colors = info['colors'] as List<Color>;
            final items = _categories[name] ?? [];
            final completed = _completedCounts[name] ?? 0;
            return _buildFeaturedCard(name, icon, colors, items.length, completed);
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'باقي الأذكار والأدعية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.mediumGreen,
          ),
        ),
        const SizedBox(height: 12),
        ...otherCategoryNames.map((name) {
          final items = _categories[name] ?? [];
          final completed = _completedCounts[name] ?? 0;
          return _buildCategoryListItem(name, items.length, completed);
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFeaturedCard(
    String name,
    IconData icon,
    List<Color> colors,
    int totalCount,
    int completedCount,
  ) {
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final isDone = totalCount > 0 && completedCount == totalCount;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToCategory(name),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: Colors.white, size: 32),
                    if (isDone)
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 24)
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$completedCount/$totalCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 4,
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

  Widget _buildCategoryListItem(
      String name, int totalCount, int completedCount) {
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final isDone = totalCount > 0 && completedCount == totalCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _navigateToCategory(name),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // أيقونة التصنيف
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFF1F8E9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDone
                        ? Icons.check_circle_outline_rounded
                        : Icons.menu_book_rounded,
                    color: isDone
                        ? AppColors.mediumGreen
                        : AppColors.mintGreen,
                  ),
                ),
                const SizedBox(width: 14),
                // اسم التصنيف + شريط التقدم
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF263238),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDone
                                ? AppColors.mediumGreen
                                : AppColors.mintGreen,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // بادج العداد
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFFE8F5E9)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$completedCount/$totalCount',
                    style: TextStyle(
                      color: isDone
                          ? AppColors.mediumGreen
                          : Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToCategory(String categoryName) async {
    final items = _categories[categoryName] ?? [];
    if (items.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AzkarListScreen(
          category: categoryName,
          allAzkar: items,
        ),
      ),
    );

    // تحديث إحصائيات الداشبورد عند العودة
    _loadData();
  }
}
