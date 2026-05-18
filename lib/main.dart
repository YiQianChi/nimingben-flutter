import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/providers.dart';
import 'config/theme.dart';
import 'pages/pages.dart';
import 'services/websocket_service.dart';
import 'store/store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const NimingBenApp(),
    ),
  );
}

/// 主题模式 provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

class NimingBenApp extends ConsumerWidget {
  const NimingBenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // 监听匹配成功 → 自动跳转聊天页
    ref.listen(chatProvider.select((s) => s.roomId), (prev, roomId) {
      if (roomId != null && prev != roomId) {
        // 匹配成功，跳转聊天
        GoRouter.of(context).go('/chat');
      }
    });

    // 监听认证状态变化 → 连接 WS
    ref.listen(authProvider.select((s) => s.token), (prev, token) {
      if (token != null && prev != token) {
        ref.read(webSocketServiceProvider).connect(token);
      }
    });

    return MaterialApp.router(
      title: '匿名本',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}

// ===== 路由 =====
final _router = GoRouter(
  initialLocation: '/match',
  redirect: (context, state) {
    // 路由守卫：根据 auth 状态重定向
    // 注意：这里无法直接读取 Riverpod provider，
    // 在页面级别做跳转控制更可靠
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/match',
      builder: (context, state) => const MatchPage(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    // 兼容旧路径
    GoRoute(
      path: '/',
      redirect: (context, state) => '/match',
    ),
  ],
);
