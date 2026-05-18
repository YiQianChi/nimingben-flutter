import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

/// WS 连接状态
enum WSState { disconnected, connecting, connected, reconnecting }

/// WebSocket 服务 — 核心通信层
///
/// 功能：
/// - 连接/断开/重连（指数退避 + 随机抖动）
/// - 心跳 ping/pong（超时自动断连重连）
/// - 事件分发（match_success / new_msg / typing 等）
/// - 统一消息格式 { event, data }
class WebSocketService {
  WebSocketChannel? _channel;
  WSState _state = WSState.disconnected;
  String? _token;
  int _reconnectAttempts = 0;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _missedHeartbeats = 0;
  StreamSubscription? _subscription;

  /// 事件处理器映射
  final Map<String, List<Function(Map<String, dynamic>)>> _handlers = {};

  /// 状态变化回调
  void Function(WSState)? onStateChanged;

  WSState get state => _state;

  void _setState(WSState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }

  // ===== 连接 =====

  void connect(String token) {
    if (_state == WSState.connected || _state == WSState.connecting) return;
    _token = token;
    _doConnect();
  }

  void _doConnect() {
    _setState(WSState.connecting);
    final uri = Uri.parse('${AppConfig.wsBase}?token=$_token');

    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // 连接成功后启动心跳
      _startHeartbeat();
      _reconnectAttempts = 0;
      _setState(WSState.connected);
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _cleanup();
    _setState(WSState.disconnected);
  }

  void _cleanup() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _missedHeartbeats = 0;
  }

  // ===== 发送 =====

  void send(String event, [Map<String, dynamic>? data]) {
    if (_state != WSState.connected) return;
    final msg = jsonEncode({'event': event, if (data != null) 'data': data});
    _channel?.sink.add(msg);
  }

  // ===== 事件 =====

  void on(String event, Function(Map<String, dynamic>) handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
  }

  void off(String event, [Function(Map<String, dynamic>)? handler]) {
    if (handler == null) {
      _handlers.remove(event);
    } else {
      _handlers[event]?.remove(handler);
    }
  }

  void _dispatch(String event, Map<String, dynamic> data) {
    final handlers = _handlers[event];
    if (handlers != null) {
      for (final h in handlers) {
        h(data);
      }
    }
  }

  // ===== 内部处理 =====

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = msg['event'] as String? ?? '';
      final data = (msg['data'] as Map<String, dynamic>?) ?? msg;

      // 心跳回复
      if (event == 'pong') {
        _missedHeartbeats = 0;
        return;
      }

      _dispatch(event, data);
    } catch (e) {
      // 忽略解析错误
    }
  }

  void _onError(dynamic error) {
    _scheduleReconnect();
  }

  void _onDone() {
    if (_state != WSState.disconnected) {
      _scheduleReconnect();
    }
  }

  // ===== 心跳 =====

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _missedHeartbeats = 0;
    _heartbeatTimer = Timer.periodic(AppConfig.heartbeatInterval, (_) {
      if (_state == WSState.connected) {
        _missedHeartbeats++;
        if (_missedHeartbeats > AppConfig.maxMissedHeartbeats) {
          // 心跳超时，强制重连
          _cleanup();
          _scheduleReconnect();
          return;
        }
        send('ping');
      }
    });
  }

  // ===== 重连（指数退避 + 随机抖动） =====

  void _scheduleReconnect() {
    _cleanup();
    if (_reconnectAttempts >= AppConfig.maxReconnectAttempts) {
      _setState(WSState.disconnected);
      return;
    }

    _setState(WSState.reconnecting);
    _reconnectAttempts++;

    // 指数退避 + 随机抖动
    final baseMs = AppConfig.reconnectBaseDelay.inMilliseconds;
    final maxMs = AppConfig.reconnectMaxDelay.inMilliseconds;
    final delayMs = (baseMs * (1 << (_reconnectAttempts - 1))).clamp(0, maxMs);
    final jitterMs = (delayMs * 0.3 * (_random() - 0.5)).round(); // ±15% 抖动
    final totalMs = (delayMs + jitterMs).abs().clamp(baseMs, maxMs);

    _reconnectTimer = Timer(Duration(milliseconds: totalMs), () {
      if (_token != null) _doConnect();
    });
  }

  double _random() => DateTime.now().microsecondsSinceEpoch % 1000 / 1000;
}

/// 全局 WS 服务 provider
final webSocketServiceProvider = Provider<WebSocketService>((ref) => WebSocketService());
