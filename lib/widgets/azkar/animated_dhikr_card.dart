import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

/// كارد الذكر المتحرك الذي يُقلَّص ويختفي عند اكتمال العدّ
class AnimatedDhikrCard extends StatefulWidget {
  final Map<String, dynamic> dhikr;
  final int remainingCount;
  final VoidCallback onTap;
  final VoidCallback onCompleted;

  const AnimatedDhikrCard({
    super.key,
    required this.dhikr,
    required this.remainingCount,
    required this.onTap,
    required this.onCompleted,
  });

  @override
  State<AnimatedDhikrCard> createState() => _AnimatedDhikrCardState();
}

class _AnimatedDhikrCardState extends State<AnimatedDhikrCard> {
  bool _isCompleted = false;
  bool _visible = true;

  @override
  void didUpdateWidget(covariant AnimatedDhikrCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remainingCount == 0 && !_isCompleted) {
      _isCompleted = true;
      setState(() => _visible = false);
      // إخطار الأب بعد انتهاء الأنيميشن
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) widget.onCompleted();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      child: _visible
          ? AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _visible ? 1.0 : 0.0,
              child: _buildCardContent(),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildCardContent() {
    final text = widget.dhikr['text'] ?? '';
    final description = widget.dhikr['description'] ?? '';
    final reference = widget.dhikr['reference'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isCompleted ? null : widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // نص الذكر (يمين في سياق RTL)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.8,
                          color: Color(0xFF212121),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (description.toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          description,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (reference.toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'المصدر: $reference',
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // عداد التكرار (يسار)
                _buildCounterBadge(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterBadge() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: Text(
          '${widget.remainingCount}',
          key: ValueKey<int>(widget.remainingCount),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
