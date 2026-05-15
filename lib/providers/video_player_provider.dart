import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player_pip/index.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    show VideoViewType;
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/media_track.dart';

/// Route-scoped video state: playback, overlays, PiP, timers, and display options.
class VideoPlayerProvider extends ChangeNotifier {
  VideoPlayerProvider({
    required MediaTrack initialTrack,
    List<MediaTrack>? playlist,
  })  : _currentTrack = initialTrack,
        _playlist = List<MediaTrack>.from(playlist ?? [initialTrack]) {
    _volumeController.showSystemUI = false;
    unawaited(_volumeController.getVolume().then((v) {
      _systemVolume = v.clamp(0.0, 1.0);
      notifyListeners();
    }));
    _volumeSub = _volumeController.addListener(
      (value) {
        _systemVolume = value.clamp(0.0, 1.0);
        notifyListeners();
      },
      fetchInitialVolume: false,
    );
    unawaited(_bootstrapBrightness());
    _createController();
  }

  final VolumeController _volumeController = VolumeController.instance;
  StreamSubscription<double>? _volumeSub;

  final ScreenBrightness _screenBrightness = ScreenBrightness.instance;
  StreamSubscription<double>? _systemBrightnessSub;
  bool _useSystemBrightness = true;
  bool _appBrightnessChanged = false;

  MediaTrack _currentTrack;
  final List<MediaTrack> _playlist;

  VideoPlayerController? _controller;
  bool _initFailed = false;

  bool _showControls = true;
  bool _touchLocked = false;
  bool _rotationLocked = false;
  bool _isFullScreen = true;
  bool _loopOne = false;
  int _speedIndex = 2;
  bool _volumeMuted = false;
  double _volumeBeforeMute = 1.0;
  double _systemVolume = 1.0;
  double _brightnessLevel = 1.0;
  Timer? _sleepTimer;
  /// Last sleep-timer choice (null = off). Stays selected after the sheet closes;
  /// remains after the countdown finishes until the user turns it off.
  Duration? _sleepPreset;
  Timer? _autoHideTimer;

  /// Last aspect ratio we pushed to the UI via [notifyListeners] (see [_onControllerTick]).
  double _lastNotifiedAspect = 0;

  /// Bumps when [controller] is recreated so stale async work is ignored.
  int _controllerEpoch = 0;
  bool _providerDisposed = false;

  static const List<double> playbackSpeedSteps = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  int get playbackSpeedStepIndex => _speedIndex.clamp(0, playbackSpeedSteps.length - 1);

  MediaTrack get currentTrack => _currentTrack;
  List<MediaTrack> get playlist => List.unmodifiable(_playlist);
  VideoPlayerController? get controller => _controller;
  bool get initFailed => _initFailed;
  bool get showControls => _showControls;
  bool get touchLocked => _touchLocked;
  bool get rotationLocked => _rotationLocked;
  bool get isFullScreen => _isFullScreen;
  bool get loopOne => _loopOne;
  double get playbackSpeed =>
      playbackSpeedSteps[_speedIndex.clamp(0, playbackSpeedSteps.length - 1)];
  bool get volumeMuted => _volumeMuted;
  /// Selected sleep duration for UI (independent of whether the timer is still ticking).
  Duration? get sleepTimerPreset => _sleepPreset;
  double get systemVolume => _systemVolume;
  double get brightnessLevel => _brightnessLevel;
  bool get useSystemBrightness => _useSystemBrightness;

  Future<void> _bootstrapBrightness() async {
    try {
      final canSystem = await _screenBrightness.canChangeSystemBrightness;
      _useSystemBrightness = canSystem;
      if (_useSystemBrightness) {
        final v = await _screenBrightness.system;
        _brightnessLevel = v.clamp(0.0, 1.0);
        _systemBrightnessSub = _screenBrightness.onSystemScreenBrightnessChanged.listen(
          (systemValue) {
            if (!_useSystemBrightness) return;
            _brightnessLevel = systemValue.clamp(0.0, 1.0);
            notifyListeners();
          },
          onError: (_) => _useSystemBrightness = false,
        );
      } else {
        final appValue = await _screenBrightness.application;
        _brightnessLevel = appValue.clamp(0.0, 1.0);
      }
      notifyListeners();
    } catch (_) {
      _useSystemBrightness = false;
    }
  }

  Future<void> setBrightness(double value) async {
    final v = value.clamp(0.0, 1.0);
    _brightnessLevel = v;
    if (_useSystemBrightness) {
      await _screenBrightness.setSystemScreenBrightness(v);
    } else {
      _appBrightnessChanged = true;
      await _screenBrightness.setApplicationScreenBrightness(v);
    }
    notifyListeners();
  }

  Future<void> setSystemVolume(double value) async {
    final v = value.clamp(0.0, 1.0);
    _systemVolume = v;
    _volumeMuted = v < 0.01;
    await _volumeController.setVolume(v);
    notifyListeners();
  }

  Future<void> toggleMute() async {
    if (_volumeMuted) {
      _volumeMuted = false;
      await _volumeController.setVolume(_volumeBeforeMute.clamp(0.0, 1.0));
    } else {
      _volumeBeforeMute = _systemVolume;
      _volumeMuted = true;
      await _volumeController.setVolume(0);
    }
    notifyListeners();
  }

  bool _wakelockOn = false;

  Future<void> _syncWakelock({required bool shouldKeepAwake}) async {
    if (_wakelockOn == shouldKeepAwake) return;
    _wakelockOn = shouldKeepAwake;
    if (shouldKeepAwake) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  void _onControllerTick() {
    final c = _controller;
    if (c == null) return;
    unawaited(_syncWakelock(shouldKeepAwake: c.value.isPlaying));
    _armAutoHideIfPlaying();

    final ar = c.value.aspectRatio;
    if (ar > 0 && (ar - _lastNotifiedAspect).abs() > 0.02) {
      _lastNotifiedAspect = ar;
      notifyListeners();
    }
  }

  void _createController() {
    _controllerEpoch++;
    final epoch = _controllerEpoch;
    final old = _controller;
    _controller?.removeListener(_onControllerTick);
    _controller = null;
    _lastNotifiedAspect = 0;
    _initFailed = false;
    notifyListeners();

    unawaited(_attachVideo(epoch, old));
  }

  Future<void> _attachVideo(int epoch, VideoPlayerController? old) async {
    if (old != null) {
      try {
        await old.dispose();
      } catch (_) {}
    }
    if (_providerDisposed || epoch != _controllerEpoch) return;

    // Platform view: reliable picture with overlays; texture can stay black under
    // [Transform.scale] on some Android GPUs.
    final viewType = VideoViewType.platformView;

    final c = VideoPlayerController.file(
      File(_currentTrack.path),
      viewType: viewType,
    );
    _controller = c;
    c.addListener(_onControllerTick);
    notifyListeners();

    try {
      await c.initialize();
    } catch (_) {
      c.removeListener(_onControllerTick);
      if (identical(_controller, c)) {
        _controller = null;
      }
      try {
        await c.dispose();
      } catch (_) {}
      if (!_providerDisposed && epoch == _controllerEpoch) {
        _initFailed = true;
        notifyListeners();
      }
      return;
    }

    if (_providerDisposed || epoch != _controllerEpoch) {
      c.removeListener(_onControllerTick);
      if (identical(_controller, c)) {
        _controller = null;
      }
      try {
        await c.dispose();
      } catch (_) {}
      return;
    }

    try {
      await c.setLooping(_loopOne);
      await c.setPlaybackSpeed(playbackSpeed);
      await c.setVolume(1.0);
      await c.play();
      await _syncWakelock(shouldKeepAwake: true);
    } catch (_) {
      c.removeListener(_onControllerTick);
      if (identical(_controller, c)) {
        _controller = null;
      }
      try {
        await c.dispose();
      } catch (_) {}
      if (!_providerDisposed && epoch == _controllerEpoch) {
        _initFailed = true;
        notifyListeners();
      }
    }
    if (!_providerDisposed && epoch == _controllerEpoch) {
      notifyListeners();
    }
  }

  Future<void> switchToTrack(MediaTrack track) async {
    if (_currentTrack.path == track.path) return;
    _currentTrack = track;
    _createController();
  }

  Future<void> syncSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> enterFullScreenVideoOrientations() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await syncSystemUi();
  }

  Future<void> enterPortraitOrientations() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await syncSystemUi();
  }

  @override
  void dispose() {
    _providerDisposed = true;
    _controllerEpoch++;
    _autoHideTimer?.cancel();
    _stopSleepTimerOnly();
    _sleepPreset = null;
    _controller?.removeListener(_onControllerTick);
    final c = _controller;
    _controller = null;
    if (c != null) {
      unawaited(c.dispose());
    }
    _volumeSub?.cancel();
    _volumeController.removeListener();
    _systemBrightnessSub?.cancel();
    if (_appBrightnessChanged) {
      unawaited(_screenBrightness.resetApplicationScreenBrightness());
    }
    unawaited(WakelockPlus.disable());
    unawaited(
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    );
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    super.dispose();
  }

  void toggleOverlay() {
    _showControls = !_showControls;
    notifyListeners();
    if (_showControls) {
      _armAutoHideIfPlaying();
    } else {
      _autoHideTimer?.cancel();
    }
  }

  void revealControls() {
    if (!_showControls) {
      _showControls = true;
      notifyListeners();
    }
    _armAutoHideIfPlaying();
  }

  void _armAutoHideIfPlaying() {
    _autoHideTimer?.cancel();
    final c = _controller;
    if (!_showControls || c == null || !c.value.isInitialized || !c.value.isPlaying || _touchLocked) {
      return;
    }
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      final cc = _controller;
      if (cc != null && cc.value.isPlaying && !_touchLocked) {
        _showControls = false;
        notifyListeners();
      }
    });
  }

  void toggleTouchLock() {
    _touchLocked = !_touchLocked;
    if (_touchLocked) {
      _showControls = true;
      _autoHideTimer?.cancel();
    }
    notifyListeners();
  }

  Future<void> applyRotationLock(BuildContext context, bool locked) async {
    _rotationLocked = locked;
    if (!locked) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
      if (landscape) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    }
    notifyListeners();
    await syncSystemUi();
  }

  Future<void> toggleFullScreen() async {
    _isFullScreen = !_isFullScreen;
    if (_isFullScreen) {
      await enterFullScreenVideoOrientations();
    } else {
      await enterPortraitOrientations();
    }
    notifyListeners();
    await syncSystemUi();
  }

  Future<void> toggleLoop() async {
    _loopOne = !_loopOne;
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      await c.setLooping(_loopOne);
    }
    notifyListeners();
  }

  Future<void> cyclePlaybackSpeed() async {
    _speedIndex = (_speedIndex + 1) % playbackSpeedSteps.length;
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      try {
        await c.setPlaybackSpeed(playbackSpeed);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setPlaybackSpeedIndex(int index) async {
    _speedIndex = index.clamp(0, playbackSpeedSteps.length - 1);
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      try {
        await c.setPlaybackSpeed(playbackSpeed);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    notifyListeners();
    _armAutoHideIfPlaying();
  }

  Future<void> seekBy(Duration offset) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final total = c.value.duration;
    var next = c.value.position + offset;
    if (next < Duration.zero) {
      next = Duration.zero;
    } else if (total > Duration.zero && next > total) {
      next = total;
    }
    await c.seekTo(next);
    notifyListeners();
  }

  Future<void> skipBack10() => seekBy(const Duration(seconds: -10));
  Future<void> skipForward10() => seekBy(const Duration(seconds: 10));

  void _stopSleepTimerOnly() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  /// Clears the selected duration and stops any active countdown.
  void turnOffSleepTimer() {
    _stopSleepTimerOnly();
    _sleepPreset = null;
    notifyListeners();
  }

  /// Remembers [fromNow] as the selected preset, closes countdown logic, and starts a new timer.
  void scheduleSleepTimer(Duration fromNow) {
    _sleepPreset = fromNow;
    _stopSleepTimerOnly();
    _sleepTimer = Timer(fromNow, () async {
      final c = _controller;
      if (c != null) await c.pause();
      _stopSleepTimerOnly();
      notifyListeners();
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
    notifyListeners();
  }

  Future<bool> tryEnterPip() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return false;
    try {
      final supported = await VideoPlayerPip.isPipSupported();
      if (!supported) return false;
      final ar = c.value.aspectRatio <= 0 ? 16 / 9 : c.value.aspectRatio;
      const w = 320;
      final h = (w / ar).round().clamp(180, 640);
      return await c.enterPipMode(width: w, height: h);
    } catch (_) {
      return false;
    }
  }

  Future<void> pauseForAudioHandoff() async {
    await _controller?.pause();
  }
}
