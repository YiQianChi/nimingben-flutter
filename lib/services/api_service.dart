import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../models/user.dart';

/// HTTP API 服务 — 对接 Go 后端所有 REST 接口
class ApiService {
  final Dio _dio;
  String? _token;

  ApiService() : _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBase,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        // 统一解包：后端返回 { code, data, message }
        final body = response.data;
        if (body is Map && body.containsKey('data')) {
          response.data = body['data'];
        }
        handler.next(response);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _token = null;
        }
        handler.next(error);
      },
    ));
  }

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  // ===== 认证 =====

  /// 匿名访客登录（首页自动调用）
  Future<Map<String, dynamic>> guestLogin(String deviceId) async {
    final res = await _dio.post('/auth/guest', data: {'deviceId': deviceId});
    return res.data;
  }

  /// 手机号+验证码登录
  Future<Map<String, dynamic>> loginBySms(String phone, String code) async {
    final res = await _dio.post('/auth/login/sms', data: {'phone': phone, 'code': code});
    return res.data;
  }

  /// 手机号+密码登录
  Future<Map<String, dynamic>> loginByPassword(String phone, String password) async {
    final res = await _dio.post('/auth/login/password', data: {'phone': phone, 'password': password});
    return res.data;
  }

  /// 注册
  Future<Map<String, dynamic>> register(String phone, String code, String password) async {
    final res = await _dio.post('/auth/register', data: {'phone': phone, 'code': code, 'password': password});
    return res.data;
  }

  /// 发送验证码
  Future<void> sendSmsCode(String phone) async {
    await _dio.post('/auth/sms/send', data: {'phone': phone});
  }

  /// 重置密码
  Future<void> resetPassword(String phone, String code, String newPassword) async {
    await _dio.post('/auth/reset-password', data: {'phone': phone, 'code': code, 'newPassword': newPassword});
  }

  /// Token 验证
  Future<Map<String, dynamic>> verifyToken() async {
    final res = await _dio.get('/auth/verify');
    return res.data;
  }

  // ===== 匹配 =====

  /// 开始匹配
  Future<Map<String, dynamic>> startMatch(String gender, String age) async {
    final res = await _dio.post('/match/start', data: {'gender': gender, 'age': age});
    return res.data;
  }

  /// 取消匹配
  Future<void> cancelMatch() async {
    await _dio.post('/match/cancel');
  }

  // ===== 聊天 =====

  /// 获取访客剩余匹配次数
  Future<int> getMatchRemaining() async {
    final res = await _dio.get('/user/match-remaining');
    return res.data['remaining'] ?? 0;
  }

  // ===== 用户 =====

  /// 获取/设置 IP 属地开关
  Future<bool> getShowLocation() async {
    final res = await _dio.get('/user/show-location');
    return res.data['showLocation'] ?? false;
  }

  Future<void> setShowLocation(bool show) async {
    await _dio.post('/user/show-location', data: {'showLocation': show});
  }

  /// 举报用户
  Future<void> reportUser(String roomId, String reason, {String? detail}) async {
    await _dio.post('/report', data: {
      'roomId': roomId,
      'reason': reason,
      'detail': detail,
    });
  }

  // ===== 上传 =====

  /// 上传图片
  Future<String> uploadImage(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post('/upload/image', data: formData);
    return res.data['url'];
  }

  /// 上传语音
  Future<String> uploadVoice(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post('/upload/voice', data: formData);
    return res.data['url'];
  }
}

/// 全局 API 服务 provider
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
