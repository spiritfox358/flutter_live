class TimeUtil {
  /// Format a DateTime as a relative time string in Chinese.
  /// "刚刚" / "X分钟前" / "HH:mm" / "昨天 HH:mm" / "星期X" / "MM-dd"
  static String formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return "刚刚";
    }
    if (diff.inMinutes < 60) {
      return "${diff.inMinutes}分钟前";
    }

    // Today: show "HH:mm"
    if (_isSameDay(dt, now)) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    // Yesterday: show "昨天 HH:mm"
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (_isSameDay(dt, yesterday)) {
      return "昨天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    // Within this week: show weekday name
    if (diff.inDays < 7 && dt.weekday != now.weekday) {
      const weekdays = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"];
      return weekdays[dt.weekday - 1];
    }

    // This year: show "MM-dd"
    if (dt.year == now.year) {
      return "${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    }

    // Older: show "yyyy-MM-dd"
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
