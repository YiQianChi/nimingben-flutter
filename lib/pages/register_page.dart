import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../store/store.dart';

/// 注册页面 — 手机号+验证码+密码
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  // ===== 手机号验证 =====
  bool _isValidPhone(String phone) {
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);
  }

  // ===== 发送验证码 =====
  Future<void> _sendSmsCode() async {
    final phone = _phoneController.text.trim();
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

  // ===== 注册 =====
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showSnackBar('请先同意用户协议和隐私政策');
      return;
    }

    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text.trim();

    try {
      await ref.read(apiServiceProvider).register(phone, code, password);
      if (!mounted) return;

      // 注册成功，自动登录
      final loginSuccess = await ref.read(authProvider.notifier).loginByPassword(phone, password);
      if (!mounted) return;

      if (loginSuccess) {
        context.go('/match');
      } else {
        _showSnackBar('注册成功，请手动登录');
        context.pop();
      }
    } catch (e) {
      _showSnackBar('注册失败：$e');
    }
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('注册'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTheme.spacingLG),

              // 标题
              Text(
                '创建账号',
                style: AppTheme.heading2.copyWith(
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '注册后可享受无限匹配等更多功能',
                style: AppTheme.bodyMedium.copyWith(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // 手机号
              TextFormField(
                controller: _phoneController,
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

              // 验证码
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _codeController,
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
                      onPressed: _countdown > 0 ? null : _sendSmsCode,
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
              const SizedBox(height: AppTheme.spacingMD),

              // 密码
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: AppTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: '请设置密码（6-20位）',
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
                  if (v == null || v.trim().isEmpty) return '请设置密码';
                  if (v.trim().length < 6) return '密码至少6位';
                  if (v.trim().length > 20) return '密码最多20位';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingMD),

              // 确认密码
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                style: AppTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: '请确认密码',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请确认密码';
                  if (v.trim() != _passwordController.text.trim()) return '两次密码不一致';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingLG),

              // 用户协议
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _agreedToTerms,
                      onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                      activeColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      children: [
                        Text(
                          '我已阅读并同意 ',
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // TODO: 用户协议页面
                          },
                          child: const Text(
                            '《用户协议》',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        Text(
                          ' 和 ',
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // TODO: 隐私政策页面
                          },
                          child: const Text(
                            '《隐私政策》',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // 注册按钮
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _register,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.textOnPrimary,
                          ),
                        )
                      : const Text('注册'),
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),
            ],
          ),
        ),
      ),
    );
  }
}
