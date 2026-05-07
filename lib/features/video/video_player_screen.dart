import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../models/media_track.dart';
import '../../providers/audio_player_provider.dart';
import '../../widgets/glass_card.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.track});

  final MediaTrack track;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _initFailed = false;
  bool _isFullScreen = true;
  bool _showOverlayControls = false;
  double _videoScale = 1.0;
  double _baseVideoScale = 1.0;
  bool _isWakelockEnabled = false;
  final VolumeController _systemVolumeController = VolumeController.instance;
  StreamSubscription<double>? _systemVolumeSub;
  final ScreenBrightness _screenBrightnessController = ScreenBrightness.instance;
  StreamSubscription<double>? _systemBrightnessSub;
  double _systemVolume = 1.0;
  double _brightnessLevel = 1.0;
  bool _useSystemBrightness = true;
  bool _appBrightnessChanged = false;
  _DragZone _activeDragZone = _DragZone.none;
  double _dragStartDy = 0;
  double _dragStartValue = 0;

  Future<void> _syncSystemUiMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _syncWakelock({required bool shouldKeepAwake}) async {
    if (_isWakelockEnabled == shouldKeepAwake) return;
    _isWakelockEnabled = shouldKeepAwake;
    if (shouldKeepAwake) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSystemUiMode());
    _systemVolumeController.showSystemUI = false;
    _systemVolumeController.getVolume().then((value) {
      if (!mounted) return;
      setState(() => _systemVolume = value.clamp(0.0, 1.0));
    });
    _systemVolumeSub = _systemVolumeController.addListener(
      (value) {
        if (!mounted) return;
        setState(() => _systemVolume = value.clamp(0.0, 1.0));
      },
      fetchInitialVolume: false,
    );
    _setupBrightnessControl();
    final ctrl = VideoPlayerController.file(File(widget.track.path));
    _controller = ctrl;
    ctrl.addListener(() {
      _syncWakelock(shouldKeepAwake: ctrl.value.isPlaying);
      if (mounted) setState(() {});
    });
    ctrl.initialize().then((_) {
      if (mounted) {
        setState(() {});
        ctrl.play();
        ctrl.setVolume(1.0);
        _syncWakelock(shouldKeepAwake: true);
      }
    }).catchError((_) {
      if (mounted) setState(() => _initFailed = true);
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.disable();
    _systemVolumeSub?.cancel();
    _systemVolumeController.removeListener();
    _systemBrightnessSub?.cancel();
    if (_appBrightnessChanged) {
      unawaited(_screenBrightnessController.resetApplicationScreenBrightness());
    }
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _setupBrightnessControl() async {
    try {
      final canChangeSystem = await _screenBrightnessController.canChangeSystemBrightness;
      if (!mounted) return;
      _useSystemBrightness = canChangeSystem;

      if (_useSystemBrightness) {
        final value = await _screenBrightnessController.system;
        if (!mounted) return;
        setState(() => _brightnessLevel = value.clamp(0.0, 1.0));
        _systemBrightnessSub =
            _screenBrightnessController.onSystemScreenBrightnessChanged.listen(
          (systemValue) {
            if (!mounted || !_useSystemBrightness) return;
            setState(() => _brightnessLevel = systemValue.clamp(0.0, 1.0));
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _useSystemBrightness = false);
          },
        );
      } else {
        final appValue = await _screenBrightnessController.application;
        if (!mounted) return;
        setState(() => _brightnessLevel = appValue.clamp(0.0, 1.0));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _useSystemBrightness = false);
    }
  }

  Future<void> _toggleFullScreen() async {
    final next = !_isFullScreen;
    setState(() => _isFullScreen = next);
    if (next) {
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
    await _syncSystemUiMode();
  }

  Future<void> _playAudioOnly(BuildContext context) async {
    await _controller?.pause();
    if (!context.mounted) return;
    context.read<AudioPlayerProvider>().playTrack(widget.track);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('অডিও চালু হয়েছে'),
          duration: Duration(seconds: 2),
        ),
      );
    await _syncSystemUiMode();
    if (mounted) {
      setState(() {
        _showOverlayControls = false;
      });
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  void _handleVerticalDragStart(DragStartDetails details, BoxConstraints constraints) {
    final halfWidth = constraints.maxWidth / 2;
    _activeDragZone = details.localPosition.dx >= halfWidth ? _DragZone.right : _DragZone.left;
    _dragStartDy = details.localPosition.dy;
    _dragStartValue = _activeDragZone == _DragZone.right ? _systemVolume : _brightnessLevel;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_activeDragZone == _DragZone.none) return;
    final dragDistance = _dragStartDy - details.localPosition.dy;
    final normalizedDelta = dragDistance / constraints.maxHeight;
    final nextValue = (_dragStartValue + normalizedDelta).clamp(0.0, 1.0);
    if (_activeDragZone == _DragZone.right) {
      _systemVolume = nextValue;
      _systemVolumeController.setVolume(_systemVolume);
    } else {
      _brightnessLevel = nextValue;
      if (_useSystemBrightness) {
        unawaited(_screenBrightnessController.setSystemScreenBrightness(_brightnessLevel));
      } else {
        _appBrightnessChanged = true;
        unawaited(_screenBrightnessController.setApplicationScreenBrightness(_brightnessLevel));
      }
    }
    if (mounted) setState(() {});
  }

  void _handleVerticalDragEnd(_) {
    _activeDragZone = _DragZone.none;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      extendBodyBehindAppBar: true,
      appBar: null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_initFailed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassCard(
                  child: Text(
                    'ভিডিও লোড করা যায়নি। কোডেক বা ফাইল ফরম্যাট সাপোর্ট নাও হতে পারে।',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ),
              ),
            )
          else if (c != null && c.value.isInitialized)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      setState(() => _showOverlayControls = !_showOverlayControls);
                      await _syncSystemUiMode();
                    },
                    onDoubleTap: _toggleFullScreen,
                    onScaleStart: (_) => _baseVideoScale = _videoScale,
                    onScaleUpdate: (details) {
                      if (details.pointerCount < 2) return;
                      setState(() {
                        _videoScale = (_baseVideoScale * details.scale).clamp(0.6, 4.0);
                      });
                    },
                    onVerticalDragStart: (details) =>
                        _handleVerticalDragStart(details, constraints),
                    onVerticalDragUpdate: (details) =>
                        _handleVerticalDragUpdate(details, constraints),
                    onVerticalDragEnd: _handleVerticalDragEnd,
                    onVerticalDragCancel: () => _handleVerticalDragEnd(null),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRect(
                          child: Transform.scale(
                            scale: _videoScale,
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              child: Builder(
                                builder: (context) {
                                  final ar =
                                      c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio;
                                  final sz = c.value.size;
                                  final w = sz.width > 0 ? sz.width : 1920.0;
                                  final h = sz.height > 0 ? sz.height : w / ar;
                                  return SizedBox(width: w, height: h, child: VideoPlayer(c));
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: AppColors.cyanAccent)),
          if (_showOverlayControls)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c != null && c.value.isInitialized) ...[
                      VideoProgressIndicator(
                        c,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: AppColors.cyanAccent,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            onPressed: () {
                              if (c.value.isPlaying) {
                                c.pause();
                              } else {
                                c.play();
                              }
                              setState(() {});
                            },
                            icon: Icon(
                              c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: _isFullScreen ? 'ফুলস্ক্রিন বন্ধ' : 'ফুলস্ক্রিন',
                            onPressed: _toggleFullScreen,
                            icon: Icon(
                              _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (!_isFullScreen) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.violetGlow,
                          ),
                          onPressed: () => _playAudioOnly(context),
                          icon: const Icon(Icons.headphones_rounded),
                          label: const Text('শুধু অডিও চালান'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ভিডিও বন্ধ করে ব্যাকগ্রাউন্ডে শুধু সাউন্ড চালাবে',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_showOverlayControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: kToolbarHeight,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            widget.track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).appBarTheme.titleTextStyle ??
                                Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_activeDragZone != _DragZone.none)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 20,
              left: _activeDragZone == _DragZone.left ? 20 : null,
              right: _activeDragZone == _DragZone.right ? 20 : null,
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _activeDragZone == _DragZone.right
                          ? Icons.volume_up_rounded
                          : Icons.brightness_6_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${((_activeDragZone == _DragZone.right ? _systemVolume : _brightnessLevel) * 100).round()}%',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _DragZone { none, left, right }
