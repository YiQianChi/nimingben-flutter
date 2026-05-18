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

class _MatchPageState extends ConsumerState<MatchPage> {
  String _selectedGender = '';
  String _selectedAge = '';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    // 从 SharedPreferences 恢复偏好
    // 简化实现，实际可用 shared_preferences provider
  }

  bool get _canMatch =>
      _selectedGender.isNotEmpty && _selectedAge.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final chat = ref.watch(chatProvider);
    final isGuestOutOfChances = auth.isGuest && auth.matchRemaining <= 0;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Logo
              const Text(
                '匿名本',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
              const SizedBox(height: 48),

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
              const SizedBox(height: 32),

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
              const SizedBox(height: 48),

              // 访客剩余次数
              if (auth.isGuest)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '访客剩余匹配次数：${auth.matchRemaining}',
                    style: TextStyle(color: Colors.white.withAlpha(153)),
                  ),
                ),

              // 匹配按钮
              if (chat.isMatching) ...[
                const CircularProgressIndicator(color: Color(0xFFE8A87C)),
                const SizedBox(height: 16),
                Text(
                  '正在匹配中...${chat.queuePosition > 0 ? " (排队第${chat.queuePosition}位)" : ""}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.read(chatProvider.notifier).cancelMatch(),
                  child: const Text('取消匹配', style: TextStyle(color: Colors.redAccent)),
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

  Widget _buildGenderChip(String value, String label, IconData icon, Color color) {
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
      await ref.read(chatProvider.notifier).startMatch(_selectedGender, _selectedAge);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匹配失败：$e')),
        );
      }
    }
  }
}
