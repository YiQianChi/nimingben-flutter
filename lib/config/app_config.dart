/// 应用配置 — 所有环境相关的常量集中管理
class AppConfig {
  // ===== 后端地址 =====
  static const String apiBase = 'https://10.10.30.180:3000/api';
  static const String wsBase = 'wss://10.10.30.180:3000/ws';

  // 生产环境（上线后切换）
  // static const String apiBase = 'https://www.nimingben.com/api';
  // static const String wsBase = 'wss://www.nimingben.com/ws';

  // ===== 匹配超时 =====
  static const Duration matchTimeout = Duration(seconds: 30);

  // ===== WebSocket =====
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const int maxMissedHeartbeats = 3;

  // ===== 重连 =====
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectBaseDelay = Duration(seconds: 1);
  static const Duration reconnectMaxDelay = Duration(seconds: 32);

  // ===== 访客限制 =====
  static const int guestMatchLimit = 3;

  // ===== 闪图 =====
  static const int flashDuration = 8; // 秒

  // ===== 语音 =====
  static const int maxVoiceDuration = 60; // 秒
}
