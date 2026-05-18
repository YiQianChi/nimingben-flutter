# 匿名本 Flutter 版

匿名随机匹配聊天 App — Flutter 跨端实现，一套代码出 **iOS + Android**。

## 项目结构

```
lib/
├── main.dart                 # 入口 + 路由
├── config/
│   ├── app_config.dart       # 环境配置（API地址、超时等）
│   └── providers.dart        # 全局 Provider
├── models/
│   ├── user.dart             # 用户模型
│   ├── message.dart          # 消息模型（文本/图片/闪图/语音）
│   ├── match_result.dart     # 匹配结果模型
│   └── models.dart           # 导出桶
├── services/
│   ├── api_service.dart      # HTTP API 服务（Dio）
│   ├── websocket_service.dart # WebSocket 服务（心跳+重连）
│   └── services.dart         # 导出桶
├── store/
│   ├── auth_store.dart       # 认证状态（匿名登录/手机登录）
│   ├── chat_store.dart       # 聊天状态（匹配/消息/房间）
│   └── store.dart            # 导出桶
├── pages/
│   ├── match_page.dart       # 匹配页（首页）
│   └── chat_page.dart        # 聊天页
├── widgets/
│   └── confetti_overlay.dart # 庆祝动画
└── utils/
    ├── format.dart           # 时间/属地格式化
    └── connectivity.dart     # 连接状态
```

## 核心特性

- ✅ **匿名访客登录** — 首次打开自动匿名登录，零门槛
- ✅ **手机号登录** — 验证码/密码两种方式
- ✅ **随机匹配** — 性别/年龄偏好选择
- ✅ **实时聊天** — WebSocket（心跳+自动重连+指数退避）
- ✅ **消息类型** — 文本/图片/闪图/语音/撤回
- ✅ **回复引用** — 消息回复功能
- ✅ **消息状态** — sending → sent → delivered → read
- ✅ **IP 属地** — 匹配成功展示对方属地
- ✅ **暗色主题** — 与 Web 版一致的深色 UI

## 后端对接

后端完全复用现有 Go 服务，**零改动**：

- REST API: `https://10.10.30.180:3000/api/`
- WebSocket: `wss://10.10.30.180:3000/ws`

切换环境只需修改 `lib/config/app_config.dart` 中的地址。

## 开发环境搭建

### 1. 安装 Flutter

```bash
# macOS
brew install flutter

# Windows
# 下载 https://docs.flutter.dev/get-started/install/windows

# Linux
snap install flutter --classic
```

### 2. 验证环境

```bash
flutter doctor
```

### 3. 安装依赖

```bash
cd nimingben-flutter
flutter pub get
```

### 4. 运行

```bash
# iOS 模拟器（需要 Mac）
flutter run

# Android 模拟器
flutter run

# 指定设备
flutter devices
flutter run -d <device_id>
```

## 构建

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS（需要 Mac + Xcode）
flutter build ios --release
```

## 上架

### Android
1. 生成签名密钥：`keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nimingben`
2. 配置 `android/app/build.gradle` 签名
3. `flutter build appbundle --release`
4. 上传 Google Play / 国内应用市场

### iOS
1. Apple 开发者账号（$99/年）
2. Xcode 配置 Bundle ID + 证书
3. `flutter build ios --release`
4. Xcode → Product → Archive → Upload to App Store Connect

## 技术栈

| 层 | 技术 |
|---|------|
| UI | Flutter 3.x + Material 3 |
| 状态管理 | Riverpod 2.x |
| 路由 | GoRouter |
| 网络 | Dio 5.x |
| WebSocket | web_socket_channel |
| 本地存储 | SharedPreferences + FlutterSecureStorage |
| 图片 | CachedNetworkImage + ImagePicker |
| 语音 | Record + Audioplayers |

## 与 Web 版的对应关系

| Web (Vue3) | Flutter |
|---|---------|
| `composables/useAuth.ts` | `store/auth_store.dart` |
| `composables/useWebSocket.ts` | `services/websocket_service.dart` |
| `composables/useMatchLogic.ts` | `pages/match_page.dart` + `store/chat_store.dart` |
| `composables/useChatLogic.ts` | `pages/chat_page.dart` + `store/chat_store.dart` |
| `stores/chat/` | `store/chat_store.dart` |
| `utils/api.ts` | `services/api_service.dart` |
| `stores/user.ts` | `store/auth_store.dart` |
