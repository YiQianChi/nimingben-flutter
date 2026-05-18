import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../models/match_result.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'auth_store.dart';

/// 聊天状态
class ChatState {
  final String? roomId;
  final PartnerInfo? partner;
  final bool isMatching;
  final int queuePosition;
  final bool isPartnerTyping;
  final bool isPartnerLeft;
  final bool isInChat;
  final List<Message> messages;
  final ReplyData? replyTo;

  const ChatState({
    this.roomId,
    this.partner,
    this.isMatching = false,
    this.queuePosition = 0,
    this.isPartnerTyping = false,
    this.isPartnerLeft = false,
    this.isInChat = false,
    this.messages = const [],
    this.replyTo,
  });

  ChatState copyWith({
    String? roomId,
    PartnerInfo? partner,
    bool? isMatching,
    int? queuePosition,
    bool? isPartnerTyping,
    bool? isPartnerLeft,
    bool? isInChat,
    List<Message>? messages,
    ReplyData? replyTo,
    bool clearRoom = false,
    bool clearReplyTo = false,
  }) {
    return ChatState(
      roomId: clearRoom ? null : (roomId ?? this.roomId),
      partner: clearRoom ? null : (partner ?? this.partner),
      isMatching: isMatching ?? this.isMatching,
      queuePosition: queuePosition ?? this.queuePosition,
      isPartnerTyping: isPartnerTyping ?? this.isPartnerTyping,
      isPartnerLeft: isPartnerLeft ?? this.isPartnerLeft,
      isInChat: isInChat ?? this.isInChat,
      messages: messages ?? this.messages,
      replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
    );
  }
}

/// Chat Notifier — 管理匹配+聊天全流程
class ChatNotifier extends StateNotifier<ChatState> {
  final ApiService _api;
  final WebSocketService _ws;
  final AuthNotifier _auth;
  Timer? _matchTimeoutTimer;

  ChatNotifier(this._api, this._ws, this._auth) : super(const ChatState()) {
    _registerWSHandlers();
  }

  void _registerWSHandlers() {
    _ws.on('match_success', _onMatchSuccess);
    _ws.on('match_timeout', _onMatchTimeout);
    _ws.on('match_offline', _onMatchOffline);
    _ws.on('match_waiting', _onMatchWaiting);
    _ws.on('new_msg', _onNewMessage);
    _ws.on('msg_reply', _onMsgReply);
    _ws.on('msg_sent', _onMsgSent);
    _ws.on('msg_revoked', _onMsgRevoked);
    _ws.on('msg_status', _onMsgStatus);
    _ws.on('typing', _onTyping);
    _ws.on('stop-typing', _onStopTyping);
    _ws.on('partner_left', _onPartnerLeft);
  }

  // ===== 匹配 =====

  Future<void> startMatch(String gender, String age) async {
    state = state.copyWith(isMatching: true, isPartnerLeft: false);

    // 确保 WS 已连接
    if (_ws.state != WSState.connected && _auth.state.token != null) {
      _ws.connect(_auth.state.token!);
      // 等待连接（最多3秒）
      await Future.delayed(const Duration(seconds: 3));
    }

    try {
      await _api.startMatch(gender, age);
    } catch (e) {
      state = state.copyWith(isMatching: false);
      rethrow;
    }

    // 匹配超时计时器
    _matchTimeoutTimer?.cancel();
    _matchTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (state.isMatching) {
        state = state.copyWith(isMatching: false);
      }
    });
  }

  Future<void> cancelMatch() async {
    _matchTimeoutTimer?.cancel();
    try {
      await _api.cancelMatch();
    } catch (_) {}
    state = state.copyWith(isMatching: false);
  }

  // ===== 发消息 =====

  void sendText(String text, {ReplyData? replyTo}) {
    if (state.roomId == null) return;
    final tempMid = 'me_${DateTime.now().millisecondsSinceEpoch}';

    // 乐观更新：立即显示消息
    final msg = Message(
      mid: tempMid,
      from: MessageFrom.me,
      type: MessageType.text,
      content: text,
      time: DateTime.now().toIso8601String(),
      replyTo: replyTo,
    );
    state = state.copyWith(messages: [...state.messages, msg], clearReplyTo: true);

    // 通过 WS 发送
    _ws.send('send_msg', {
      'roomId': state.roomId,
      'type': 'text',
      'content': text,
      'tempId': tempMid,
      if (replyTo != null) 'replyTo': replyTo.mid,
    });
  }

  void sendImage(String imageUrl) {
    if (state.roomId == null) return;
    final tempMid = 'me_${DateTime.now().millisecondsSinceEpoch}';

    final msg = Message(
      mid: tempMid,
      from: MessageFrom.me,
      type: MessageType.image,
      content: '[图片]',
      time: DateTime.now().toIso8601String(),
      imageUrl: imageUrl,
    );
    state = state.copyWith(messages: [...state.messages, msg]);

    _ws.send('send_msg', {
      'roomId': state.roomId,
      'type': 'image',
      'imageUrl': imageUrl,
      'tempId': tempMid,
    });
  }

  void sendVoice(String audioUrl, int duration) {
    if (state.roomId == null) return;
    final tempMid = 'me_${DateTime.now().millisecondsSinceEpoch}';

    final msg = Message(
      mid: tempMid,
      from: MessageFrom.me,
      type: MessageType.voice,
      content: '[语音]',
      time: DateTime.now().toIso8601String(),
      audioUrl: audioUrl,
      voiceDuration: duration,
    );
    state = state.copyWith(messages: [...state.messages, msg]);

    _ws.send('send_msg', {
      'roomId': state.roomId,
      'type': 'voice',
      'audioUrl': audioUrl,
      'duration': duration,
      'tempId': tempMid,
    });
  }

  void sendFlash(String imageUrl, {int duration = 8}) {
    if (state.roomId == null) return;
    final tempMid = 'me_${DateTime.now().millisecondsSinceEpoch}';

    final msg = Message(
      mid: tempMid,
      from: MessageFrom.me,
      type: MessageType.flash,
      content: '[闪图]',
      time: DateTime.now().toIso8601String(),
      imageUrl: imageUrl,
      isFlash: true,
      flashDuration: duration,
    );
    state = state.copyWith(messages: [...state.messages, msg]);

    _ws.send('send_msg', {
      'roomId': state.roomId,
      'type': 'flash',
      'imageUrl': imageUrl,
      'duration': duration,
      'tempId': tempMid,
    });
  }

  // ===== 撤回 =====

  void revokeMessage(String msgId) {
    if (state.roomId == null) return;
    _ws.send('revoke_msg', {'roomId': state.roomId, 'msgId': msgId});

    // 本地立即标记撤回
    final updated = state.messages.map((m) {
      if (m.mid == msgId) {
        return m.copyWith(type: MessageType.revoked, content: '消息已撤回', revoked: true);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  // ===== 正在输入 =====

  void sendTyping() {
    _ws.send('typing', {'roomId': state.roomId});
  }

  void sendStopTyping() {
    _ws.send('stop-typing', {'roomId': state.roomId});
  }

  // ===== 离开聊天 =====

  void leaveChat() {
    if (state.roomId != null) {
      _ws.send('leave_chat', {'roomId': state.roomId});
    }
    _clearRoom();
  }

  void _clearRoom() {
    _matchTimeoutTimer?.cancel();
    state = state.copyWith(clearRoom: true, isMatching: false, isInChat: false, messages: []);
  }

  // ===== 举报 =====

  Future<void> reportUser(String reason, {String? detail}) async {
    if (state.roomId == null) return;
    await _api.reportUser(state.roomId!, reason, detail: detail);
  }

  // ===== 回复 =====

  void setReplyTo(Message msg) {
    state = state.copyWith(
      replyTo: ReplyData(mid: msg.mid, text: msg.content),
    );
  }

  void clearReplyTo() {
    state = state.copyWith(clearReplyTo: true);
  }

  // ===== WS 事件处理 =====

  void _onMatchSuccess(Map<String, dynamic> data) {
    _matchTimeoutTimer?.cancel();
    final result = MatchResult.fromJson(data);
    state = state.copyWith(
      roomId: result.roomId,
      partner: result.partner,
      isMatching: false,
      isInChat: true,
      isPartnerLeft: false,
      messages: [],
    );
  }

  void _onMatchTimeout(Map<String, dynamic> _) {
    state = state.copyWith(isMatching: false);
  }

  void _onMatchOffline(Map<String, dynamic> _) {
    state = state.copyWith(isMatching: false);
  }

  void _onMatchWaiting(Map<String, dynamic> data) {
    if (data['position'] != null) {
      state = state.copyWith(queuePosition: data['position'] as int);
    }
  }

  void _onNewMessage(Map<String, dynamic> data) {
    final msg = Message.fromWS(data, isMe: false);
    state = state.copyWith(messages: [...state.messages, msg]);

    // 自动 ACK
    if (state.roomId != null && msg.mid.isNotEmpty) {
      _ws.send('msg_ack', {'roomId': state.roomId, 'msgId': msg.mid});
      if (state.isInChat) {
        _ws.send('msg_read', {'roomId': state.roomId, 'msgId': msg.mid});
      }
    }
  }

  void _onMsgReply(Map<String, dynamic> data) {
    final msg = Message.fromWS(data, isMe: false);
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  void _onMsgSent(Map<String, dynamic> data) {
    // 替换 tempId → 真实 msgId
    final tempId = data['tempId'] as String?;
    final realId = data['msgId'] as String?;
    if (tempId != null && realId != null) {
      final updated = state.messages.map((m) {
        if (m.mid == tempId) {
          return m.copyWith(mid: realId, status: MessageStatus.sent);
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updated);
    }
  }

  void _onMsgRevoked(Map<String, dynamic> data) {
    final msgId = data['msgId'] as String?;
    if (msgId != null) {
      final updated = state.messages.map((m) {
        if (m.mid == msgId) {
          return m.copyWith(type: MessageType.revoked, content: '消息已撤回', revoked: true);
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updated);
    }
  }

  void _onMsgStatus(Map<String, dynamic> data) {
    final msgId = data['msgId'] as String?;
    final status = data['status'] as String?;
    if (msgId != null && status != null) {
      final s = status == 'delivered' ? MessageStatus.delivered
          : status == 'read' ? MessageStatus.read
          : null;
      if (s != null) {
        final updated = state.messages.map((m) {
          if (m.mid == msgId) return m.copyWith(status: s);
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
      }
    }
  }

  void _onTyping(Map<String, dynamic> _) {
    state = state.copyWith(isPartnerTyping: true);
  }

  void _onStopTyping(Map<String, dynamic> _) {
    state = state.copyWith(isPartnerTyping: false);
  }

  void _onPartnerLeft(Map<String, dynamic> _) {
    state = state.copyWith(isPartnerLeft: true);
  }
}

/// Chat provider
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final ws = ref.watch(webSocketServiceProvider);
  final auth = ref.watch(authProvider.notifier);
  return ChatNotifier(api, ws, auth);
});
