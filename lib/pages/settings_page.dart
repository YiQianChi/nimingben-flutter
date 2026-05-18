import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_config.dart';
import '../store/store.dart';
import '../services/api_service.dart';

/// 设置页面
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _showLocation = false;
  bool _notificationsEnabled = true;
  bool _isDarkMode = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final api = ref.read(apiServiceProvider);
      final showLoc = await api.getShowLocation();
      if (mounted) {
        setState(() {
          _showLocation = showLoc;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('设置', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8A87C)))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // ===== 隐私 =====
                _buildSectionHeader('隐私'),
                _buildSwitchTile(
                  icon: Icons.location_on,
                  title: 'IP属地显示',
                  subtitle: '在聊天中展示你的IP属地',
                  value: _showLocation,
                  onChanged: _onShowLocationChanged,
                ),
                const SizedBox(height: 8),

                // ===== 通知 =====
                _buildSectionHeader('通知'),
                _buildSwitchTile(
                  icon: Icons.notifications,
                  title: '消息通知',
                  subtitle: '接收新消息和匹配通知',
                  value: _notificationsEnabled,
                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                ),
                const SizedBox(height: 8),

                // ===== 外观 =====
                _buildSectionHeader('外观'),
                _buildSwitchTile(
                  icon: Icons.dark_mode,
                  title: '深色模式',
                  subtitle: '使用深色主题',
                  value: _isDarkMode,
                  onChanged: (v) => setState(() => _isDarkMode = v),
                ),
                const SizedBox(height: 8),

                // ===== 关于 =====
                _buildSectionHeader('关于'),
                _buildInfoTile(
                  icon: Icons.info_outline,
                  title: '关于匿名本',
                  value: '匿名随机匹配聊天',
                ),
                _buildInfoTile(
                  icon: Icons.verified,
                  title: '版本号',
                  value: 'v${AppConfig.appVersion}',
                ),
                _buildInfoTile(
                  icon: Icons.code,
                  title: '开源地址',
                  value: 'GitHub',
                  onTap: () {
                    // TODO: 打开 GitHub 页面
                  },
                ),
                const SizedBox(height: 16),

                // ===== 退出登录 =====
                if (auth.isLoggedIn && !auth.isGuest)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _onLogout,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '退出登录',
                          style: TextStyle(color: Colors.redAccent, fontSize: 16),
                        ),
                      ),
                    ),
                  ),

                // 访客提示
                if (auth.isGuest)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A4E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFE8A87C), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '你当前是访客身份，剩余匹配${auth.matchRemaining}次。登录后可无限匹配。',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => context.go('/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE8A87C),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('登录', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFE8A87C),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFE8A87C), size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFFE8A87C),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFE8A87C), size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
                ),
                Text(value, style: const TextStyle(color: Colors.white38, fontSize: 13)),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onShowLocationChanged(bool value) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.setShowLocation(value);
      setState(() => _showLocation = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('设置失败：$e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _onLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('确认退出', style: TextStyle(color: Colors.white)),
        content: const Text('退出登录后将使用访客身份', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/');
    }
  }
}
