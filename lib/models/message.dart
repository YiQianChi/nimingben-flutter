import 'package:flutter/foundation.dart';

/// 消息模型
class Message {
  final String mid;
  final MessageFrom from;
  final MessageType type;
  final String content;
  final String time;
  final ReplyData? replyTo;
  final bool revoked;

  // 图片
  final String? imageUrl;

  // 闪图
  final bool isFlash;
  final int? flashDuration;
  final ValueNotifier<bool> flashOpened;
  final ValueNotifier<bool> flashDestroyed;

  // 语音
  final String? audioUrl;
  final int? voiceDuration;

  // 状态
  final MessageStatus status;

  Message({
    required this.mid,
    required this.from,
    required this.type,
    required this.content,
    required this.time,
    this.replyTo,
    this.revoked = false,
    this.imageUrl,
    this.isFlash = false,
    this.flashDuration,
    bool flashOpened = false,
    bool flashDestroyed = false,
    this.audioUrl,
    this.voiceDuration,
    this.status = MessageStatus.sending,
  })  : flashOpened = ValueNotifier(flashOpened),
        flashDestroyed = ValueNotifier(flashDestroyed);

  factory Message.fromWS(Map<String, dynamic> data, {required bool isMe}) {
    final msgType = _parseType(data['type'] ?? 'text');
    return Message(
      mid: data['msgId'] ?? '${isMe ? 'me' : 'them'}_${DateTime.now().millisecondsSinceEpoch}',
      from: isMe ? MessageFrom.me : MessageFrom.them,
      type: msgType,
      content: _extractContent(data, msgType),
      time: data['time'] ?? DateTime.now().toIso8601String(),
      replyTo: data['replyTo'] != null
          ? ReplyData(mid: data['replyTo'], text: data['content'] ?? '')
          : null,
      imageUrl: data['imageUrl'],
      isFlash: msgType == MessageType.flash,
      flashDuration: data['duration'] ?? 8,
      audioUrl: data['audioUrl'],
      voiceDuration: data['duration'] ?? 0,
      status: isMe ? MessageStatus.sending : MessageStatus.delivered,
    );
  }

  static String _extractContent(Map<String, dynamic> data, MessageType type) {
    switch (type) {
      case MessageType.text:
        return data['content'] ?? '';
      case MessageType.image:
        return '[图片]';
      case MessageType.flash:
        return '[闪图]';
      case MessageType.voice:
        return '[语音]';
      case MessageType.revoked:
        return '消息已撤回';
      case MessageType.system:
        return data['content'] ?? '';
    }
  }

  static MessageType _parseType(String type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'flash':
        return MessageType.flash;
      case 'voice':
        return MessageType.voice;
      case 'revoked':
        return MessageType.revoked;
      default:
        return MessageType.text;
    }
  }

  Message copyWith({
    String? mid,
    MessageFrom? from,
    MessageType? type,
    String? content,
    String? time,
    ReplyData? replyTo,
    bool? revoked,
    String? imageUrl,
    bool? isFlash,
    int? flashDuration,
    bool? flashOpened,
    bool? flashDestroyed,
    String? audioUrl,
    int? voiceDuration,
    MessageStatus? status,
  }) {
    return Message(
      mid: mid ?? this.mid,
      from: from ?? this.from,
      type: type ?? this.type,
      content: content ?? this.content,
      time: time ?? this.time,
      replyTo: replyTo ?? this.replyTo,
      revoked: revoked ?? this.revoked,
      imageUrl: imageUrl ?? this.imageUrl,
      isFlash: isFlash ?? this.isFlash,
      flashDuration: flashDuration ?? this.flashDuration,
      flashOpened: flashOpened ?? this.flashOpened.value,
      flashDestroyed: flashDestroyed ?? this.flashDestroyed.value,
      audioUrl: audioUrl ?? this.audioUrl,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      status: status ?? this.status,
    );
  }
}

enum MessageFrom { me, them, system }

enum MessageType { text, image, flash, voice, revoked, system }

enum MessageStatus { sending, sent, delivered, read }

class ReplyData {
  final String mid;
  final String text;
  const ReplyData({required this.mid, required this.text});
}
