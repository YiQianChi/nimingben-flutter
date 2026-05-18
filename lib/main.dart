import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'config/providers.dart';
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

class NimingBenApp extends ConsumerWidget {
  const NimingBenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16213E),
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE8A87C),
          secondary: Color(0xFFE8A87C),
        ),
      ),
      routerConfig: _router,
    );
  }
}

// ===== 路由 =====
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MatchPage(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const ChatPage(),
    ),
  ],
);
