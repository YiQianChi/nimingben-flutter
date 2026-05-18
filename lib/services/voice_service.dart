import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

/// 语音录制状态
enum VoiceRecordState {
  idle,      // 空闲
  recording, // 录制中
  paused,    // 暂停
}

/// 语音播放状态
enum VoicePlayState {
  idle,      // 空闲
  playing,   // 播放中
  paused,    // 暂停
}

/// 语音录制 + 播放服务
class VoiceService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  VoiceRecordState _recordState = VoiceRecordState.idle;
  VoicePlayState _playState = VoicePlayState.idle;

  String? _currentRecordingPath;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  Timer? _playbackTimer;

  /// 录制状态变化回调
  void Function(VoiceRecordState)? onRecordStateChanged;
  /// 录制时长变化回调（秒）
  void Function(int)? onRecordingDurationChanged;
  /// 音量变化回调 (0.0 - 1.0)
  void Function(double)? onAmplitudeChanged;
  /// 播放状态变化回调
  void Function(VoicePlayState)? onPlayStateChanged;
  /// 播放进度回调（毫秒）
  void Function(int)? onPlaybackPositionChanged;

  VoiceRecordState get recordState => _recordState;
  VoicePlayState get playState => _playState;
  int get recordingDuration => _recordingDuration;
  bool get isRecording => _recordState == VoiceRecordState.recording;
  bool get isPlaying => _playState == VoicePlayState.playing;

  static const int maxDuration = 60; // 最长60秒

  // ===== 麦克风权限 =====

  /// 请求麦克风权限
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// 检查麦克风权限
  Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  // ===== 录制 =====

  /// 开始录制
  Future<bool> startRecording() async {
    if (_recordState == VoiceRecordState.recording) return false;

    // 检查权限
    final hasPermission = await requestMicrophonePermission();
    if (!hasPermission) return false;

    // 检查录制能力
    if (!await _recorder.hasPermission()) return false;

    // 生成临时文件路径
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentRecordingPath = '${tempDir.path}/voice_$timestamp.m4a';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: _currentRecordingPath!,
      );

      _recordState = VoiceRecordState.recording;
      _recordingDuration = 0;
      onRecordStateChanged?.call(_recordState);
      onRecordingDurationChanged?.call(_recordingDuration);

      // 启动录制计时器
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _recordingDuration++;
        onRecordingDurationChanged?.call(_recordingDuration);

        // 最长60秒自动停止
        if (_recordingDuration >= maxDuration) {
          stopRecording();
        }
      });

      // 启动音量监听
      _startAmplitudeMonitoring();

      return true;
    } catch (e) {
      _recordState = VoiceRecordState.idle;
      onRecordStateChanged?.call(_recordState);
      return false;
    }
  }

  /// 停止录制并返回文件路径和时长
  Future<VoiceRecordResult?> stopRecording() async {
    if (_recordState != VoiceRecordState.recording) return null;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      final path = await _recorder.stop();
      final duration = _recordingDuration;

      _recordState = VoiceRecordState.idle;
      onRecordStateChanged?.call(_recordState);

      if (path != null && duration > 0) {
        return VoiceRecordResult(
          filePath: path,
          durationSeconds: duration,
        );
      }
      return null;
    } catch (e) {
      _recordState = VoiceRecordState.idle;
      onRecordStateChanged?.call(_recordState);
      return null;
    }
  }

  /// 取消录制（删除临时文件）
  Future<void> cancelRecording() async {
    if (_recordState != VoiceRecordState.recording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      await _recorder.stop();
    } catch (_) {}

    // 删除临时文件
    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _recordState = VoiceRecordState.idle;
    _recordingDuration = 0;
    onRecordStateChanged?.call(_recordState);
    onRecordingDurationChanged?.call(0);
    onAmplitudeChanged?.call(0);
  }

  /// 音量监听
  void _startAmplitudeMonitoring() {
    // 使用定时器轮询音量
    Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (_recordState != VoiceRecordState.recording) {
        timer.cancel();
        return;
      }
      try {
        final amplitude = await _recorder.getAmplitude();
        // 将 dB 值映射到 0.0 - 1.0 范围
        // amplitude.current 通常在 -60dB 到 0dB
        final normalized = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
        onAmplitudeChanged?.call(normalized);
      } catch (_) {}
    });
  }

  // ===== 播放 =====

  /// 播放语音
  Future<void> playVoice(String url, {String? localPath}) async {
    if (_playState == VoicePlayState.playing) return;

    try {
      // 优先播放本地文件，否则播放远程 URL
      final source = (localPath != null && File(localPath).existsSync())
          ? DeviceFileSource(localPath)
          : UrlSource(url);

      await _player.play(source);

      _playState = VoicePlayState.playing;
      onPlayStateChanged?.call(_playState);

      // 监听播放进度
      _player.onPositionChanged.listen((position) {
        onPlaybackPositionChanged?.call(position.inMilliseconds);
      });

      // 监听播放完成
      _player.onPlayerComplete.listen((_) {
        _playState = VoicePlayState.idle;
        onPlayStateChanged?.call(_playState);
        onPlaybackPositionChanged?.call(0);
      });
    } catch (e) {
      _playState = VoicePlayState.idle;
      onPlayStateChanged?.call(_playState);
    }
  }

  /// 暂停播放
  Future<void> pausePlayback() async {
    if (_playState != VoicePlayState.playing) return;
    await _player.pause();
    _playState = VoicePlayState.paused;
    onPlayStateChanged?.call(_playState);
  }

  /// 继续播放
  Future<void> resumePlayback() async {
    if (_playState != VoicePlayState.paused) return;
    await _player.resume();
    _playState = VoicePlayState.playing;
    onPlayStateChanged?.call(_playState);
  }

  /// 停止播放
  Future<void> stopPlayback() async {
    await _player.stop();
    _playState = VoicePlayState.idle;
    onPlayStateChanged?.call(_playState);
    onPlaybackPositionChanged?.call(0);
  }

  // ===== 临时文件管理 =====

  /// 清理所有语音临时文件
  Future<void> cleanTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final voiceDir = Directory(tempDir.path);
      final files = voiceDir.listSync();
      for (final file in files) {
        if (file is File && file.path.contains('voice_') && file.path.endsWith('.m4a')) {
          // 删除超过1小时的临时文件
          final stat = await file.stat();
          final age = DateTime.now().difference(stat.modified);
          if (age.inHours >= 1) {
            await file.delete();
          }
        }
      }
    } catch (_) {}
  }

  /// 释放资源
  void dispose() {
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
  }
}

/// 录制结果
class VoiceRecordResult {
  final String filePath;
  final int durationSeconds;

  const VoiceRecordResult({
    required this.filePath,
    required this.durationSeconds,
  });
}

// ===== Riverpod Providers =====

/// VoiceService 单例 provider
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// 录制状态 provider
final voiceRecordStateProvider = StateProvider<VoiceRecordState>((ref) {
  return VoiceRecordState.idle;
});

/// 播放状态 provider
final voicePlayStateProvider = StateProvider<VoicePlayState>((ref) {
  return VoicePlayState.idle;
});

/// 当前录制时长 provider
final recordingDurationProvider = StateProvider<int>((ref) => 0);

/// 当前音量 provider
final recordingAmplitudeProvider = StateProvider<double>((ref) => 0.0);

/// 当前播放的消息 mid（用于UI高亮）
final playingVoiceMsgIdProvider = StateProvider<String?>((ref) => null);
