import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../store/store.dart';

/// 登录方式 Tab
enum LoginTab { sms, password }

/// 登录页面 — 手机号+验证码 / 手机号+密码 / 匿名游客
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 短信登录表单
  final _smsPhoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final _smsFormKey = GlobalKey<FormState>();

  // 密码登录表单
  final _pwdPhoneController = TextEditingController();
  final _pwdController = TextEditingController();
  final _pwdFormKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _smsPhoneController.dispose();
    _smsCodeController.dispose();
    _pwdPhoneController.dispose();
    _pwdController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ===== 验证码倒计时 =====
  void _startCountdown() {
    _countdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 0) {
        timer.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  // ===== 发送验证码 =====
  Future<void> _sendSmsCode(String phone) async {
    if (!_isValidPhone(phone)) {
      _showSnackBar('请输入正确的手机号');
      return;
    }
    try {
      await ref.read(apiServiceProvider).sendSmsCode(phone);
      _startCountdown();
      _showSnackBar('验证码已发送');
    } catch (e) {
      _showSnackBar('发送失败：$e');
    }
  }

  // ===== 手机号验证 =====
  bool _isValidPhone(String phone) {
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);
  }

  // ===== 短信登录 =====
  Future<void> _loginBySms() async {
    if (!_smsFormKey.currentState!.validate()) return;

    final phone = _smsPhoneController.text.trim();
    final code = _smsCodeController.text.trim();

    final success = await ref.read(authProvider.notifier).loginBySms(phone, code);
    if (!mounted) return;

    if (success) {
      context.go('/match');
    } else {
      _showSnackBar('登录失败，请检查手机号和验证码');
    }
  }

  // ===== 密码登录 =====
  Future<void> _loginByPassword() async {
    if (!_pwdFormKey.currentState!.validate()) return;

    final phone = _pwdPhoneController.text.trim();
    final password = _pwdController.text.trim();

    final success = await ref.read(authProvider.notifier).loginByPassword(phone, password);
    if (!mounted) return;

    if (success) {
      context.go('/match');
    } else {
      _showSnackBar('登录失败，请检查手机号和密码');
    }
  }

  // ===== 匿名游客进入 =====
  Future<void> _guestLogin() async {
    // auth_store 已自动匿名登录，直接跳转
    context.go('/match');
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),

              // Logo + 标题
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        size: 36,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '匿名本',
                      style: AppTheme.heading1.copyWith(
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '遇见陌生人的美好',
                      style: AppTheme.bodyMedium.copyWith(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // 登录方式 Tab
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppTheme.textOnPrimary,
                  unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  labelStyle: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: '验证码登录'),
                    Tab(text: '密码登录'),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),

              // Tab 内容
              SizedBox(
                height: 280,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSmsForm(isLoading),
                    _buildPasswordForm(isLoading),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),

              // 注册入口
              Center(
                child: TextButton(
                  onPressed: () => context.push('/register'),
                  child: RichText(
                    text: TextSpan(
                      text: '还没有账号？',
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                      children: const [
                        TextSpan(
                          text: '立即注册',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // 分割线
              Row(
                children: [
                  Expanded(child: Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '或者',
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextHint : AppTheme.textHint,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider)),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLG),

              // 匿名游客入口
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: isLoading ? null : _guestLogin,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.visibility_off_outlined,
                        size: 18,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '匿名游客，直接进入',
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingSM),

              // 游客提示
              Center(
                child: Text(
                  '游客模式仅可匹配${AppConfig.guestMatchLimit}次，登录后无限制',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextHint : AppTheme.textHint,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 验证码登录表单 =====
  Widget _buildSmsForm(bool isLoading) {
    return Form(
      key: _smsFormKey,
      child: Column(
        children: [
          // 手机号
          TextFormField(
            controller: _smsPhoneController,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            style: AppTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: '请输入手机号',
              prefixIcon: Icon(Icons.phone_android, size: 20),
              counterText: '',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请输入手机号';
              if (!_isValidPhone(v.trim())) return '手机号格式不正确';
              return null;
            },
          ),
          const SizedBox(height: AppTheme.spacingMD),

          // 验证码 + 发送按钮
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _smsCodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: AppTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: '请输入验证码',
                    prefixIcon: Icon(Icons.sms_outlined, size: 20),
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入验证码';
                    if (v.trim().length != 6) return '验证码为6位数字';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _countdown > 0
                      ? null
                      : () => _sendSmsCode(_smsPhoneController.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _countdown > 0
                        ? AppTheme.primaryColor.withAlpha(100)
                        : AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(
                    _countdown > 0 ? '${_countdown}s' : '获取验证码',
                    style: const TextStyle(fontSize: 14, color: AppTheme.textOnPrimary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLG),

          // 登录按钮
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : _loginBySms,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.textOnPrimary,
                      ),
                    )
                  : const Text('登录'),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 密码登录表单 =====
  Widget _buildPasswordForm(bool isLoading) {
    return Form(
      key: _pwdFormKey,
      child: Column(
        children: [
          // 手机号
          TextFormField(
            controller: _pwdPhoneController,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            style: AppTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: '请输入手机号',
              prefixIcon: Icon(Icons.phone_android, size: 20),
              counterText: '',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请输入手机号';
              if (!_isValidPhone(v.trim())) return '手机号格式不正确';
              return null;
            },
          ),
          const SizedBox(height: AppTheme.spacingMD),

          // 密码
          TextFormField(
            controller: _pwdController,
            obscureText: _obscurePassword,
            style: AppTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: '请输入密码',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请输入密码';
              if (v.trim().length < 6) return '密码至少6位';
              if (v.trim().length > 20) return '密码最多20位';
              return null;
            },
          ),
          const SizedBox(height: AppTheme.spacingSM),

          // 忘记密码
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // TODO: 忘记密码页面
              },
              child: const Text('忘记密码？'),
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),

          // 登录按钮
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : _loginByPassword,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.textOnPrimary,
                      ),
                    )
                  : const Text('登录'),
            ),
          ),
        ],
      ),
    );
  }
}
