import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../store/store.dart';

/// 匹配页 — 首页，选择偏好并开始匹配
class MatchPage extends ConsumerStatefulWidget {
  const MatchPage({super.key});

  @override
  ConsumerState<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends ConsumerState<MatchPage>
    with SingleTickerProviderStateMixin {
  String _selectedGender = '';
  String _selectedAge = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadPreferences();

    // 脉冲动画
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    // 从 SharedPreferences 恢复偏好
  }

  bool get _canMatch =>
      _selectedGender.isNotEmpty && _selectedAge.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final chat = ref.watch(chatProvider);
    final isGuestOutOfChances = auth.isGuest && auth.matchRemaining <= 0;

    // 匹配中启动脉冲动画
    if (chat.isMatching) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0.0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // 顶部右侧设置按钮
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white54, size: 24),
                  onPressed: () => context.push('/settings'),
                ),
              ),

              // Logo
              const Text(
                '匿名本',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '遇见陌生人的美好',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withAlpha(153),
                ),
              ),
              const SizedBox(height: 40),

              // 性别选择
              _buildSectionTitle('选择想聊的对象'),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildGenderChip('male', '男生', Icons.male, Colors.blue),
                  const SizedBox(width: 12),
                  _buildGenderChip('female', '女生', Icons.female, Colors.pink),
                  const SizedBox(width: 12),
                  _buildGenderChip('any', '随缘', Icons.shuffle, Colors.purple),
                ],
              ),
              const SizedBox(height: 28),

              // 年龄选择
              _buildSectionTitle('年龄段'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: [
                  _buildAgeChip('18-25', '18-25'),
                  _buildAgeChip('26-35', '26-35'),
                  _buildAgeChip('36+', '36+'),
                  _buildAgeChip('any', '随缘'),
                ],
              ),
              const SizedBox(height: 40),

              // 访客剩余次数（醒目提示）
              if (auth.isGuest)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: auth.matchRemaining > 0
                        ? const Color(0xFFE8A87C).withAlpha(30)
                        : Colors.redAccent.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: auth.matchRemaining > 0
                          ? const Color(0xFFE8A87C).withAlpha(60)
                          : Colors.redAccent.withAlpha(60),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        auth.matchRemaining > 0 ? Icons.card_giftcard : Icons.block,
                        color: auth.matchRemaining > 0
                            ? const Color(0xFFE8A87C)
                            : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '访客剩余匹配次数：${auth.matchRemaining}',
                        style: TextStyle(
                          color: auth.matchRemaining > 0
                              ? const Color(0xFFE8A87C)
                              : Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // 匹配按钮 / 匹配中动画
              if (chat.isMatching) ...[
                // 脉冲+渐变色动画
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFE8A87C).withAlpha(180),
                              const Color(0xFF6C5CE7).withAlpha(180),
                              const Color(0xFFE8A87C).withAlpha(180),
                            ],
                            stops: [
                              0.0,
                              0.5 + _pulseAnimation.value * 0.2,
                              1.0,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE8A87C).withAlpha(100),
                              blurRadius: 30 * _pulseAnimation.value,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.search, color: Colors.white, size: 40),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  '正在匹配中...${chat.queuePosition > 0 ? " (排队第${chat.queuePosition}位)" : ""}',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 20),
                // 取消匹配按钮
                SizedBox(
                  width: 160,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => ref.read(chatProvider.notifier).cancelMatch(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      '取消匹配',
                      style: TextStyle(color: Colors.redAccent, fontSize: 15),
                    ),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _canMatch && !isGuestOutOfChances
                        ? _startMatch
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8A87C),
                      disabledBackgroundColor: Colors.grey.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFFE8A87C).withAlpha(80),
                    ),
                    child: Text(
                      isGuestOutOfChances
                          ? '请登录后继续匹配'
                          : !_canMatch
                              ? '请选择偏好'
                              : '开始匹配',
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),

              const Spacer(),

              // 底部访客提示
              if (auth.isGuest && !chat.isMatching)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton(
                    onPressed: () => context.push('/login'),
                    child: const Text(
                      '登录后无限匹配 →',
                      style: TextStyle(color: Color(0xFFE8A87C), fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, color: Colors.white70),
      ),
    );
  }

  Widget _buildGenderChip(
      String value, String label, IconData icon, Color color) {
    final selected = _selectedGender == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 18, color: selected ? Colors.white : color),
      label: Text(label),
      selected: selected,
      selectedColor: color,
      backgroundColor: Colors.white10,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
      onSelected: (_) => setState(() => _selectedGender = selected ? '' : value),
    );
  }

  Widget _buildAgeChip(String value, String label) {
    final selected = _selectedAge == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFE8A87C),
      backgroundColor: Colors.white10,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
      onSelected: (_) => setState(() => _selectedAge = selected ? '' : value),
    );
  }

  Future<void> _startMatch() async {
    try {
      await ref.read(chatProvider.notifier).startMatch(
            _selectedGender,
            _selectedAge,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匹配失败：$e')),
        );
      }
    }
  }
}
