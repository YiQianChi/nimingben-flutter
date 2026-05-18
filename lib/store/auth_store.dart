import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../config/providers.dart';
import '../models/user.dart';
import '../services/api_service.dart';

/// 认证状态
class AuthState {
  final User? user;
  final String? token;
  final String deviceId;
  final bool isLoading;

  const AuthState({
    this.user,
    this.token,
    required this.deviceId,
    this.isLoading = false,
  });

  bool get isLoggedIn => token != null && user != null;
  bool get isGuest => user?.isGuest ?? true;
  int get matchRemaining => user?.matchRemaining ?? 0;

  AuthState copyWith({User? user, String? token, String? deviceId, bool? isLoading}) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      deviceId: deviceId ?? this.deviceId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;
  static const _uuid = Uuid();

  AuthNotifier(this._api, this._prefs, this._secureStorage)
      : super(AuthState(deviceId: _initDeviceId(_prefs))) {
    _loadSavedAuth();
  }

  static String _initDeviceId(SharedPreferences prefs) {
    var id = prefs.getString('device_id');
    if (id == null) {
      id = _uuid.v4();
      prefs.setString('device_id', id);
    }
    return id;
  }

  Future<void> _loadSavedAuth() async {
    final savedToken = await _secureStorage.read(key: 'auth_token');
    if (savedToken != null) {
      _api.setToken(savedToken);
      try {
        final data = await _api.verifyToken();
        state = state.copyWith(
          token: savedToken,
          user: User.fromJson(data['user'] ?? data),
        );
      } catch (_) {
        // Token 失效，走匿名登录
        await _guestLogin();
      }
    } else {
      await _guestLogin();
    }
  }

  /// 匿名访客登录（首页自动调用）
  Future<void> _guestLogin() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.guestLogin(state.deviceId);
      final token = data['token'] as String;
      final user = User.fromJson(data['user'] ?? data);
      _api.setToken(token);
      await _secureStorage.write(key: 'auth_token', value: token);
      state = state.copyWith(token: token, user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 手机号+验证码登录
  Future<bool> loginBySms(String phone, String code) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.loginBySms(phone, code);
      final token = data['token'] as String;
      final user = User.fromJson(data['user'] ?? data);
      _api.setToken(token);
      await _secureStorage.write(key: 'auth_token', value: token);
      state = state.copyWith(token: token, user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  /// 手机号+密码登录
  Future<bool> loginByPassword(String phone, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.loginByPassword(phone, password);
      final token = data['token'] as String;
      final user = User.fromJson(data['user'] ?? data);
      _api.setToken(token);
      await _secureStorage.write(key: 'auth_token', value: token);
      state = state.copyWith(token: token, user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    _api.clearToken();
    await _secureStorage.delete(key: 'auth_token');
    state = AuthState(deviceId: state.deviceId);
    await _guestLogin();
  }

  /// 更新匹配剩余次数
  void setMatchRemaining(int remaining) {
    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(matchRemaining: remaining),
      );
    }
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthNotifier(api, prefs, storage);
});
