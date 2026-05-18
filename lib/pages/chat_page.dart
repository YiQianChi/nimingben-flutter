import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message.dart';
import '../store/store.dart';

/// 聊天页 — 匹配成功后进入
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
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
        title: Column(
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
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            onPressed: () => _showChatMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 对方信息标签
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
                    _buildTag(chat.partner!.location!),
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

          // 回复引用
          if (chat.replyTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF16213E),
              child: Row(
                children: [
                  const Icon(Icons.reply, color: Color(0xFFE8A87C), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chat.replyTo!.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                    onPressed: () => chatNotifier.clearReplyTo(),
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

  Widget _buildTag(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8A87C).withAlpha(40),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFFE8A87C), fontSize: 12)),
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
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(msg, notifier),
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
    );
  }

  Widget _buildMessageContent(Message msg, bool isMe, ChatNotifier notifier) {
    // 撤回
    if (msg.revoked || msg.type == MessageType.revoked) {
      return Text(
        isMe ? '你撤回了一条消息' : '对方撤回了一条消息',
        style: TextStyle(color: (isMe ? Colors.white70 : Colors.white38), fontSize: 13, fontStyle: FontStyle.italic),
      );
    }

    // 回复引用
    final replyWidget = msg.replyTo != null
        ? Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              msg.replyTo!.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: (isMe ? Colors.white70 : Colors.white54),
                fontSize: 12,
              ),
            ),
          )
        : null;

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
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38),
              ),
            ),
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
                  // 打开闪图
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
                    Icon(Icons.flash_on, color: isMe ? Colors.white : Colors.purpleAccent),
                    const SizedBox(width: 8),
                    Text(
                      msg.flashOpened ? '闪图已查看' : '点击查看闪图',
                      style: TextStyle(color: isMe ? Colors.white : Colors.purpleAccent),
                    ),
                  ],
                ),
              ),
            ),
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
                Icon(Icons.mic, color: isMe ? Colors.white : Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${msg.voiceDuration ?? 0}"',
                  style: TextStyle(color: isMe ? Colors.white : Colors.white90),
                ),
              ],
            ),
          ],
        );

      default:
        return Text(msg.content, style: TextStyle(color: isMe ? Colors.white : Colors.white90));
    }
  }

  Widget _buildInputBar(ChatNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // 附件按钮
          IconButton(
            icon: const Icon(Icons.image, color: Colors.white54),
            onPressed: () => _pickImage(notifier),
          ),
          // 输入框
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: '输入消息...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A4E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => notifier.sendTyping(),
              onSubmitted: (_) => _sendMessage(notifier),
            ),
          ),
          const SizedBox(width: 8),
          // 发送按钮
          CircleAvatar(
            backgroundColor: const Color(0xFFE8A87C),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: () => _sendMessage(notifier),
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.from == MessageFrom.me && msg.type != MessageType.revoked)
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.white70),
                title: const Text('撤回', style: TextStyle(color: Colors.white70)),
                onTap: () {
                  notifier.revokeMessage(msg.mid);
                  Navigator.pop(ctx);
                },
              ),
            if (msg.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.reply, color: Colors.white70),
                title: const Text('回复', style: TextStyle(color: Colors.white70)),
                onTap: () {
                  notifier.setReplyTo(msg);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showChatMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: const Text('举报', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
              title: const Text('离开聊天', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(chatProvider.notifier).leaveChat();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    // TODO: 举报弹窗
  }

  void _showPartnerLeftDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('对方已离开', style: TextStyle(color: Colors.white)),
        content: const Text('对方已离开聊天', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chatProvider.notifier).leaveChat();
              Navigator.of(context).pop();
            },
            child: const Text('返回', style: TextStyle(color: Color(0xFFE8A87C))),
          ),
        ],
      ),
    );
  }
}
