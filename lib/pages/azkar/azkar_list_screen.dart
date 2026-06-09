import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/arabic_utils.dart';
import '../../widgets/azkar/animated_dhikr_card.dart';

/// شاشة قائمة الأذكار التفصيلية لتصنيف معين
class AzkarListScreen extends StatefulWidget {
  final String category;
  final List<Map<String, dynamic>> allAzkar;

  const AzkarListScreen({
    super.key,
    required this.category,
    required this.allAzkar,
  });

  @override
  State<AzkarListScreen> createState() => _AzkarListScreenState();
}

class _AzkarListScreenState extends State<AzkarListScreen> {
  List<Map<String, dynamic>> _visibleAzkar = [];
  Map<String, int> _remainingCounts = {};
  int _totalCount = 0;
  int _completedCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _totalCount = widget.allAzkar.length;
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> visible = [];
    int completed = 0;

    for (var z in widget.allAzkar) {
      final id = z['id'].toString();
      final defaultCount = ArabicUtils.parseCount(z['count']);
      final remaining = prefs.getInt('azkar_remaining_$id') ?? defaultCount;

      _remainingCounts[id] = remaining;

      if (remaining == 0) {
        completed++;
      } else {
        visible.add(z);
      }
    }

    setState(() {
      _visibleAzkar = visible;
      _completedCount = completed;
      _loading = false;
    });
  }

  Future<void> _decrementCount(String id, int defaultCount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _remainingCounts[id] ?? defaultCount;

    if (current <= 0) return;

    final nextVal = current - 1;
    setState(() => _remainingCounts[id] = nextVal);
    await prefs.setInt('azkar_remaining_$id', nextVal);

    if (nextVal == 0) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _handleCardCompleted(Map<String, dynamic> z) async {
    setState(() {
      _visibleAzkar.remove(z);
      _completedCount++;
    });
  }

  Future<void> _resetCategory() async {
    final prefs = await SharedPreferences.getInstance();

    for (var z in widget.allAzkar) {
      final id = z['id'].toString();
      final countInt = ArabicUtils.parseCount(z['count']);
      await prefs.remove('azkar_remaining_$id');
      _remainingCounts[id] = countInt;
    }

    setState(() {
      _visibleAzkar = List<Map<String, dynamic>>.from(widget.allAzkar);
      _completedCount = 0;
    });

    HapticFeedback.vibrate();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalCount > 0 ? _completedCount / _totalCount : 0.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.azkarBackground,
        appBar: AppBar(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            widget.category,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.restart_alt_rounded),
              tooltip: 'إعادة تعيين الأذكار',
              onPressed: _showResetDialog,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildProgressCard(progress),
                  Expanded(
                    child: _visibleAzkar.isEmpty
                        ? _buildAllCompletedView()
                        : _buildAzkarList(),
                  ),
                ],
              ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تعيين؟'),
        content: const Text(
            'هل تريد إرجاع عدادات التكرار في هذا القسم للبدء من جديد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetCategory();
            },
            child: const Text('إعادة تعيين',
                style: TextStyle(color: AppColors.primaryGreen)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'نسبة الإنجاز: ${(_completedCount / _totalCount * 100).toInt()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              Text(
                'تمت قراءة $_completedCount من $_totalCount',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAzkarList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _visibleAzkar.length,
      itemBuilder: (context, index) {
        final z = _visibleAzkar[index];
        final id = z['id'].toString();
        final defaultCount = z['count'] as int? ?? 1;
        final remaining = _remainingCounts[id] ?? defaultCount;

        return AnimatedDhikrCard(
          key: ValueKey(id),
          dhikr: z,
          remainingCount: remaining,
          onTap: () => _decrementCount(id, defaultCount),
          onCompleted: () => _handleCardCompleted(z),
        );
      },
    );
  }

  Widget _buildAllCompletedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.mintGreen, width: 3),
              ),
              child: const Icon(
                Icons.done_all_rounded,
                size: 80,
                color: AppColors.mediumGreen,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'تقبل الله منك!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'لقد أكملت قراءة جميع أذكار هذا القسم بنجاح.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _resetCategory,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'البدء من جديد',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
