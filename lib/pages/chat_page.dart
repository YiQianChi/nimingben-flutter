import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message.dart';
import '../store/store.dart';
import '../widgets/report_dialog.dart';
import '../utils/format.dart';

/// 聊天页 — 匹配成功后进入
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    // Trigger rebuild for send button visibility
    setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final chatNotifier = ref.read(chatProvider.notifier);

    // 新消息自动滚动
    ref.listen(chatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    // 对方离开弹窗
    ref.listen(chatProvider.select((s) => s.isPartnerLeft), (prev, left) {
      if (left == true && prev != true) {
        _showPartnerLeftDialog();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 在线状态指示灯
            _buildOnlineIndicator(chat),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chat.partner?.nickname ?? '匿名用户',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                if (chat.isPartnerTyping)
                  const Text(
                    '对方正在输入...',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            onPressed: () => _showChatMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 对方信息标签（含IP属地）
          if (chat.partner != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: const Color(0xFF16213E).withAlpha(128),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (chat.partner!.gender != null)
                    _buildTag(chat.partner!.genderText),
                  if (chat.partner!.age != null)
                    _buildTag(chat.partner!.age!),
                  if (chat.partner!.location != null)
                    _buildTag(LocationFormat.format(chat.partner!.location!)),
                ],
              ),
            ),

          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: chat.messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(chat.messages[index], chatNotifier);
              },
            ),
          ),

          // 回复引用栏
          if (chat.replyTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF16213E),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8A87C),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '回复',
                          style: TextStyle(color: Color(0xFFE8A87C), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          chat.replyTo!.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                    onPressed: () => chatNotifier.clearReplyTo(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // 输入栏
          _buildInputBar(chatNotifier),
        ],
      ),
    );
  }

  /// 在线状态指示灯
  Widget _buildOnlineIndicator(ChatState chat) {
    // 如果在聊天中且对方未离开，显示在线
    final isOnline = chat.isInChat && !chat.isPartnerLeft;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? Colors.green : Colors.grey,
        boxShadow: isOnline
            ? [BoxShadow(color: Colors.green.withAlpha(100), blurRadius: 4, spreadRadius: 1)]
            : null,
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8A87C).withAlpha(40),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (text == LocationFormat.format(ref.read(chatProvider).partner?.location))
            const Icon(Icons.location_on, size: 10, color: Color(0xFFE8A87C)),
          if (text == LocationFormat.format(ref.read(chatProvider).partner?.location))
            const SizedBox(width: 2),
          Text(text, style: const TextStyle(color: Color(0xFFE8A87C), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, ChatNotifier notifier) {
    if (msg.from == MessageFrom.system) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            msg.content,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }

    final isMe = msg.from == MessageFrom.me;
    final isFailed = msg.status == MessageStatus.sending && msg.from == MessageFrom.me &&
        _isStaleMessage(msg);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 发送失败重试按钮
          if (isMe && isFailed)
            GestureDetector(
              onTap: () => _retryMessage(msg, notifier),
              child: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.error, color: Colors.redAccent, size: 18),
              ),
            ),
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageActions(msg, notifier),
              onTap: () {
                // 点击文本消息也可触发回复
                if (msg.type == MessageType.text && !msg.revoked) {
                  // 单击不做操作，长按才弹出菜单
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFFE8A87C) : const Color(0xFF2A2A4E),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: _buildMessageContent(msg, isMe, notifier),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 判断消息是否已超时（发送中状态超过10秒视为失败）
  bool _isStaleMessage(Message msg) {
    try {
      final sent = DateTime.parse(msg.time);
      return DateTime.now().difference(sent).inSeconds > 10;
    } catch (_) {
      return false;
    }
  }

  /// 重试发送失败的消息
  void _retryMessage(Message msg, ChatNotifier notifier) {
    // 移除旧消息，重新发送
    final updated = ref.read(chatProvider).messages.where((m) => m.mid != msg.mid).toList();
    // 直接通过state更新后再发送
    notifier.sendText(msg.content, replyTo: msg.replyTo);
  }

  Widget _buildMessageContent(Message msg, bool isMe, ChatNotifier notifier) {
    // 撤回
    if (msg.revoked || msg.type == MessageType.revoked) {
      return Text(
        isMe ? '你撤回了一条消息' : '对方撤回了一条消息',
        style: TextStyle(
          color: (isMe ? Colors.white70 : Colors.white38),
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // 回复引用
    final replyWidget = msg.replyTo != null
        ? Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: const Color(0xFFE8A87C).withAlpha(128), width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '你' : '对方',
                  style: TextStyle(
                    color: const Color(0xFFE8A87C).withAlpha(200),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  msg.replyTo!.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: (isMe ? Colors.white70 : Colors.white54),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        : null;

    // 时间戳
    final timeWidget = Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        TimeFormat.messageTime(msg.time),
        style: TextStyle(
          color: (isMe ? Colors.white60 : Colors.white38),
          fontSize: 10,
        ),
      ),
    );

    switch (msg.type) {
      case MessageType.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyWidget != null) replyWidget,
            Text(
              msg.content,
              style: TextStyle(color: isMe ? Colors.white : Colors.white90, fontSize: 15),
            ),
            timeWidget,
          ],
        );

      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyWidget != null) replyWidget,
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: msg.imageUrl ?? '',
                width: 180,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox(
                  width: 180,
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white38),
              ),
            ),
            timeWidget,
          ],
        );

      case MessageType.flash:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyWidget != null) replyWidget,
            GestureDetector(
              onTap: () {
                if (!msg.flashOpened) {
                  setState(() {
                    final idx = ref.read(chatProvider).messages.indexOf(msg);
                    if (idx >= 0) {
                      ref.read(chatProvider).messages[idx].flashOpened = true;
                    }
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(60),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flash_on,
                        color: isMe ? Colors.white : Colors.purpleAccent),
                    const SizedBox(width: 8),
                    Text(
                      msg.flashOpened ? '闪图已查看' : '点击查看闪图',
                      style: TextStyle(
                          color: isMe ? Colors.white : Colors.purpleAccent),
                    ),
                  ],
                ),
              ),
            ),
            timeWidget,
          ],
        );

      case MessageType.voice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replyWidget != null) replyWidget,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic,
                    color: isMe ? Colors.white : Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${msg.voiceDuration ?? 0}"',
                  style:
                      TextStyle(color: isMe ? Colors.white : Colors.white90),
                ),
              ],
            ),
            timeWidget,
          ],
        );

      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg.content,
                style: TextStyle(color: isMe ? Colors.white : Colors.white90)),
            timeWidget,
          ],
        );
    }
  }

  /// 输入栏 — 支持多行（最大4行）
  Widget _buildInputBar(ChatNotifier notifier) {
    final hasText = _inputController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 附件按钮
          IconButton(
            icon: const Icon(Icons.image, color: Colors.white54),
            onPressed: () => _pickImage(notifier),
          ),
          // 多行输入框（最大4行）
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLines: 4,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: '输入消息...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A4E),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) {
                notifier.sendTyping();
                // setState already triggered by listener
              },
              onSubmitted: (_) => _sendMessage(notifier),
            ),
          ),
          const SizedBox(width: 8),
          // 发送按钮（有文字时高亮）
          CircleAvatar(
            backgroundColor: hasText
                ? const Color(0xFFE8A87C)
                : const Color(0xFF2A2A4E),
            child: IconButton(
              icon: Icon(Icons.send,
                  color: hasText ? Colors.white : Colors.white38, size: 18),
              onPressed: hasText ? () => _sendMessage(notifier) : null,
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(ChatNotifier notifier) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final chat = ref.read(chatProvider);
    notifier.sendText(text, replyTo: chat.replyTo);
    _inputController.clear();
    notifier.sendStopTyping();
  }

  Future<void> _pickImage(ChatNotifier notifier) async {
    // TODO: image_picker 选图 + 上传
  }

  void _showMessageActions(Message msg, ChatNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示条
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 回复
            if (!msg.revoked && msg.type != MessageType.revoked)
              ListTile(
                leading: const Icon(Icons.reply, color: Color(0xFFE8A87C)),
                title: const Text('回复', style: TextStyle(color: Colors.white70)),
                onTap: () {
                  notifier.setReplyTo(msg);
                  Navigator.pop(ctx);
                  _inputFocusNode.requestFocus();
                },
              ),
            // 撤回（仅自己的消息）
            if (msg.from == MessageFrom.me && msg.type != MessageType.revoked)
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.white70),
                title:
                    const Text('撤回', style: TextStyle(color: Colors.white70)),
                onTap: () {
                  notifier.revokeMessage(msg.mid);
                  Navigator.pop(ctx);
                },
              ),
            // 复制
            if (msg.type == MessageType.text && !msg.revoked)
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.white70),
                title:
                    const Text('复制', style: TextStyle(color: Colors.white70)),
                onTap: () {
                  // TODO: 复制到剪贴板
                  Navigator.pop(ctx);
                },
              ),
            // 举报（仅对方的消息）
            if (msg.from == MessageFrom.them)
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.orange),
                title:
                    const Text('举报', style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.pop(ctx);
                  showReportDialog(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showChatMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: const Text('举报', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(ctx);
                showReportDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              title: const Text('离开聊天',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(chatProvider.notifier).leaveChat();
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPartnerLeftDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('对方已离开', style: TextStyle(color: Colors.white)),
        content:
            const Text('对方已离开聊天', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chatProvider.notifier).leaveChat();
              Navigator.of(context).pop();
            },
            child: const Text('返回',
                style: TextStyle(color: Color(0xFFE8A87C))),
          ),
        ],
      ),
    );
  }
}
