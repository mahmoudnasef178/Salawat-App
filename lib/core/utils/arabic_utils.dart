/// دوال مساعدة للغة العربية مستخدمة في أكثر من مكان بالتطبيق
abstract class ArabicUtils {
  /// تحويل أرقام إنجليزية لأرقام عربية
  /// مثال: 12 → '١٢'
  static String toArabicNum(int number) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String numStr = number.toString();
    for (int i = 0; i < english.length; i++) {
      numStr = numStr.replaceAll(english[i], arabic[i]);
    }
    return numStr;
  }

  /// تحويل وقت "HH:mm" (24 ساعة) إلى "H:mm ص/م"
  /// مثال: "14:30" → "2:30 م"
  static String fmt12Hour(String raw) {
    try {
      final p = raw.split(':');
      int h = int.parse(p[0]);
      final m = p[1];
      final suffix = h >= 12 ? 'م' : 'ص';
      if (h > 12) h -= 12;
      if (h == 0) h = 12;
      return '$h:$m $suffix';
    } catch (_) {
      return raw;
    }
  }

  /// تنسيق مدة العد التنازلي إلى نص
  /// مثال: Duration(hours: 1, minutes: 5, seconds: 3) → "1:05:03"
  static String fmtCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${_pad(m)}:${_pad(s)}';
    }
    return '${_pad(m)}:${_pad(s)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// تحويل العدد الخام (int أو String) إلى int بأمان
  static int parseCount(dynamic raw, {int fallback = 1}) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
  }
}
