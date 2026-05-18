import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

/// 连接状态 provider
final wsStateProvider = Provider<WSState>((ref) {
  final ws = ref.watch(webSocketServiceProvider);
  return ws.state;
});

/// 是否已连接
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(wsStateProvider) == WSState.connected;
});

/// 网络可用性（简化版，实际应加 connectivity_plus）
final isNetworkAvailableProvider = Provider<bool>((ref) => true);
