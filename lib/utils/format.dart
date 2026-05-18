import 'package:intl/intl.dart';

/// 时间格式化工具
class TimeFormat {
  /// 格式化消息时间
  static String messageTime(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) {
      return DateFormat.Hm().format(DateTime.now());
    }
    try {
      final dt = DateTime.parse(isoTime);
      return DateFormat.Hm().format(dt);
    } catch (_) {
      return isoTime;
    }
  }

  /// 格式化聊天时长
  static String chatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }
}

/// IP 属地格式化
class LocationFormat {
  /// 格式化 IP 属地显示
  /// 北京 → 北京
  /// 广东省深圳市 → 广东·深圳
  static String format(String? location) {
    if (location == null || location.isEmpty) return '';
    // 去掉"省""市"后缀，用 · 连接
    final parts = location
        .replaceAll('省', '·')
        .replaceAll('市', '')
        .split('·')
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.join('·');
  }
}
