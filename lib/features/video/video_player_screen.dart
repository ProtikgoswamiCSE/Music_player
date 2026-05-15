import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:video_player_pip/index.dart';

import '../../core/theme/app_theme.dart';
import '../../models/media_track.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/video_player_provider.dart';

/// Full-screen video route. Uses a route-scoped [ChangeNotifierProvider] for
/// playback, gestures, PiP, and chrome visibility.
class VideoPlayerScreen extends StatelessWidget {
  const VideoPlayerScreen({
    super.key,
    required this.track,
    this.playlist,
  });

  final MediaTrack track;
  final List<MediaTrack>? playlist;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideoPlayerProvider(initialTrack: track, playlist: playlist),
      child: const _VideoPlayerRouteBody(),
    );
  }
}

class _VideoPlayerRouteBody extends StatefulWidget {
  const _VideoPlayerRouteBody();

  @override
  State<_VideoPlayerRouteBody> createState() => _VideoPlayerRouteBodyState();
}

class _VideoPlayerRouteBodyState extends State<_VideoPlayerRouteBody> {
  static const double _minPinch = 0.75;
  static const double _maxPinch = 4.0;

  /// Pinch zoom is kept here (not in [VideoPlayerProvider]) so we do not
  /// [notifyListeners] every frame — that was cancelling the scale gesture.
  double _pinchScale = 1.0;
  double _pinchGestureStartScale = 1.0;
  int _pointersDown = 0;

  String? _trackedVideoPath;

  _DragZone _activeDragZone = _DragZone.none;
  double _dragStartDy = 0;
  double _dragStartValue = 0;

  /// Cover / contain / fit — kept here so changing fit only [setState]s this route,
  /// not [VideoPlayerProvider] (provider-wide rebuild was dropping / warping taps
  /// on the bottom bar while in landscape fullscreen).
  int _aspectIndex = 0;

  /// Ignores rapid repeat taps on fit (native surface could crash on Android).
  DateTime? _lastAspectCycleAt;

  BoxFit get _videoBoxFit {
    switch (_aspectIndex % 3) {
      case 0:
        return BoxFit.cover;
      case 1:
        return BoxFit.contain;
      default:
        return BoxFit.fill;
    }
  }

  void _cycleVideoAspect() {
    final now = DateTime.now();
    if (_lastAspectCycleAt != null &&
        now.difference(_lastAspectCycleAt!) < const Duration(milliseconds: 200)) {
      return;
    }
    _lastAspectCycleAt = now;
    context.read<VideoPlayerProvider>().revealControls();
    final next = (_aspectIndex + 1) % 3;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _aspectIndex = next);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = context.read<VideoPlayerProvider>().currentTrack.path;
    if (_trackedVideoPath != path) {
      _trackedVideoPath = path;
      setState(() {
        _pinchScale = 1.0;
        _aspectIndex = 0;
      });
    }
  }

  void _onPointerCount(PointerEvent e) {
    if (e is PointerDownEvent) {
      _pointersDown++;
    } else if (e is PointerUpEvent || e is PointerCancelEvent) {
      _pointersDown = (_pointersDown - 1).clamp(0, 8);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final player = context.read<VideoPlayerProvider>();
      await player.enterFullScreenVideoOrientations();
      if (!mounted) return;
      await player.syncSystemUi();
    });
  }

  Future<void> _playAudioOnly() async {
    final p = context.read<VideoPlayerProvider>();
    await p.pauseForAudioHandoff();
    if (!mounted) return;
    context.read<AudioPlayerProvider>().playTrack(p.currentTrack);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Audio is playing'),
          duration: Duration(seconds: 2),
        ),
      );
    await p.syncSystemUi();
    if (mounted) Navigator.of(context).pop();
  }

  void _handleVerticalDragStart(DragStartDetails details, BoxConstraints constraints) {
    if (_pointersDown > 1) {
      _activeDragZone = _DragZone.none;
      return;
    }
    final p = context.read<VideoPlayerProvider>();
    final halfWidth = constraints.maxWidth / 2;
    _activeDragZone = details.localPosition.dx >= halfWidth ? _DragZone.right : _DragZone.left;
    _dragStartDy = details.localPosition.dy;
    _dragStartValue = _activeDragZone == _DragZone.right ? p.systemVolume : p.brightnessLevel;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_activeDragZone == _DragZone.none) return;
    final p = context.read<VideoPlayerProvider>();
    final dragDistance = _dragStartDy - details.localPosition.dy;
    final normalizedDelta = dragDistance / constraints.maxHeight;
    final nextValue = (_dragStartValue + normalizedDelta).clamp(0.0, 1.0);
    if (_activeDragZone == _DragZone.right) {
      unawaited(p.setSystemVolume(nextValue));
    } else {
      unawaited(p.setBrightness(nextValue));
    }
  }

  Future<void> _toggleFullScreen(VideoPlayerProvider p) async {
    await p.toggleFullScreen();
    if (!mounted) return;
    p.revealControls();
  }

  void _handleVerticalDragEnd(_) {
    setState(() => _activeDragZone = _DragZone.none);
  }

  Future<void> _openSleepPicker(VideoPlayerProvider p) async {
    final choice = await showModalBottomSheet<Duration?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deepSpace,
      builder: (ctx) {
        return ChangeNotifierProvider<VideoPlayerProvider>.value(
          value: p,
          child: SafeArea(
            child: Consumer<VideoPlayerProvider>(
              builder: (context, p2, _) {
                final preset = p2.sleepTimerPreset;
                final maxH = MediaQuery.sizeOf(context).height * 0.55;

                ListTile buildRow(String title, Duration? value) {
                  final off = value == null;
                  final selected = off
                      ? preset == null
                      : preset != null && preset.inMilliseconds == value.inMilliseconds;
                  return ListTile(
                    title: Text(title),
                    trailing:
                        selected ? const Icon(Icons.check_rounded, color: AppColors.roseAccent) : null,
                    onTap: () => Navigator.pop(ctx, off ? Duration.zero : value),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: ListView(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Sleep timer',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                      ),
                      buildRow('Off', null),
                      buildRow('5 minutes', const Duration(minutes: 5)),
                      buildRow('10 minutes', const Duration(minutes: 10)),
                      buildRow('30 minutes', const Duration(minutes: 30)),
                      buildRow('1 hour', const Duration(hours: 1)),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    if (choice == Duration.zero) {
      p.turnOffSleepTimer();
    } else {
      p.scheduleSleepTimer(choice);
    }
  }

  Future<void> _openPlaylist(VideoPlayerProvider p) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deepSpace,
      builder: (ctx) {
        final sheetH = MediaQuery.sizeOf(context).height * 0.55;
        return SafeArea(
          child: SizedBox(
            height: sheetH,
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 1,
              minChildSize: 0.35,
              maxChildSize: 1,
              builder: (_, scroll) {
                return ListView.builder(
                  controller: scroll,
                  itemCount: p.playlist.length,
                  itemBuilder: (_, i) {
                    final t = p.playlist[i];
                    final sel = t.path == p.currentTrack.path;
                    return ListTile(
                      selected: sel,
                      leading: Icon(
                        sel ? Icons.play_circle_fill_rounded : Icons.movie_rounded,
                        color: sel ? AppColors.roseAccent : Colors.white54,
                      ),
                      title: Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await p.switchToTrack(t);
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPlaybackSettings(VideoPlayerProvider p) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.deepSpace,
      builder: (ctx) {
        return ChangeNotifierProvider<VideoPlayerProvider>.value(
          value: p,
          child: SafeArea(
            child: Consumer<VideoPlayerProvider>(
              builder: (context, p2, _) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Playback', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                      const SizedBox(height: 12),
                      const Text('Speed', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < VideoPlayerProvider.playbackSpeedSteps.length; i++)
                            ChoiceChip(
                              label: Text('${VideoPlayerProvider.playbackSpeedSteps[i]}×'),
                              selected: i == p2.playbackSpeedStepIndex,
                              onSelected: (selected) {
                                if (selected) unawaited(p2.setPlaybackSpeedIndex(i));
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Loop current video'),
                        value: p2.loopOne,
                        onChanged: (_) => p2.toggleLoop(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBrightnessSheet(VideoPlayerProvider p) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.deepSpace,
      builder: (ctx) {
        return ChangeNotifierProvider<VideoPlayerProvider>.value(
          value: p,
          child: SafeArea(
            child: Consumer<VideoPlayerProvider>(
              builder: (context, p2, _) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Brightness', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.brightness_low_rounded),
                          Expanded(
                            child: Slider(
                              value: p2.brightnessLevel,
                              onChanged: (v) => unawaited(p2.setBrightness(v)),
                            ),
                          ),
                          const Icon(Icons.brightness_high_rounded),
                        ],
                      ),
                      Text(
                        p2.useSystemBrightness ? 'System brightness' : 'In-app brightness',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _tryPip(VideoPlayerProvider p) async {
    final entered = await p.tryEnterPip();
    if (!mounted) return;
    if (!entered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Picture-in-picture is not available. Your device may not support PiP in this player mode.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<VideoPlayerProvider>();
    final c = p.controller;

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (p.initFailed)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load this video. The codec or file format may not be supported.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ),
            )
          else if (c != null && c.value.isInitialized)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(
                        ignoring: p.touchLocked,
                        child: Listener(
                          behavior: HitTestBehavior.deferToChild,
                          onPointerDown: _onPointerCount,
                          onPointerUp: _onPointerCount,
                          onPointerCancel: _onPointerCount,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              p.toggleOverlay();
                              await p.syncSystemUi();
                            },
                            onScaleStart: (_) {
                              _pinchGestureStartScale = _pinchScale;
                            },
                            onScaleUpdate: (details) {
                              if (details.pointerCount < 2) return;
                              final next =
                                  (_pinchGestureStartScale * details.scale).clamp(_minPinch, _maxPinch);
                              if (next != _pinchScale) {
                                setState(() => _pinchScale = next);
                              }
                            },
                            onVerticalDragStart: (d) => _handleVerticalDragStart(d, constraints),
                            onVerticalDragUpdate: (d) => _handleVerticalDragUpdate(d, constraints),
                            onVerticalDragEnd: _handleVerticalDragEnd,
                            onVerticalDragCancel: () => _handleVerticalDragEnd(null),
                            child: ClipRect(
                              child: RepaintBoundary(
                                child: Transform.scale(
                                  scale: _pinchScale,
                                  alignment: Alignment.center,
                                  child: SizedBox.expand(
                                    child: _VideoFitSurface(
                                      controller: c,
                                      fit: _videoBoxFit,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (p.touchLocked)
                        Positioned.fill(
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.5),
                            child: InkWell(
                              onTap: () => p.toggleTouchLock(),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.lock_rounded, size: 56, color: Colors.white),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Screen locked — tap to unlock',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: AppColors.roseAccent)),
          if (_activeDragZone != _DragZone.none)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 20,
              left: _activeDragZone == _DragZone.left ? 20 : null,
              right: _activeDragZone == _DragZone.right ? 20 : null,
              child: _dragHud(p),
            ),
          if (p.showControls && !p.touchLocked) ...[
            _buildTopBar(context, p),
            _buildLeftRail(context, p),
            _buildRightRail(context, p),
            _buildBottomChrome(context, p),
          ],
        ],
      ),
    );
  }

  Widget _dragHud(VideoPlayerProvider p) {
    final isVol = _activeDragZone == _DragZone.right;
    final v = isVol ? p.systemVolume : p.brightnessLevel;
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isVol ? Icons.volume_up_rounded : Icons.brightness_6_rounded, size: 18),
            const SizedBox(width: 8),
            Text('${(v * 100).round()}%'),
          ],
        ),
      ),
    );
  }

  Widget _roundIcon({
    required IconData icon,
    required VoidCallback? onPressed,
    double size = 22,
    String? tooltip,
  }) {
    final message = tooltip ?? '';
    final button = Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: size),
          ),
        ),
      ),
    );
    if (message.isEmpty) return button;
    return Tooltip(message: message, child: button);
  }

  Widget _buildTopBar(BuildContext context, VideoPlayerProvider p) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: PointerInterceptor(
        child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight + 4,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    p.currentTrack.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                _roundIcon(
                  icon: p.sleepTimerPreset != null ? Icons.timer_rounded : Icons.timer_outlined,
                  tooltip: 'Sleep timer',
                  onPressed: () => _openSleepPicker(p),
                ),
                const SizedBox(width: 4),
                _roundIcon(
                  icon: p.volumeMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  tooltip: 'Volume / mute',
                  onPressed: () => p.toggleMute(),
                ),
                const SizedBox(width: 4),
                _roundIcon(
                  icon: p.rotationLocked ? Icons.screen_lock_rotation_rounded : Icons.screen_rotation_rounded,
                  tooltip: 'Rotation lock',
                  onPressed: () => p.applyRotationLock(context, !p.rotationLocked),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildLeftRail(BuildContext context, VideoPlayerProvider p) {
    return Positioned(
      left: 12,
      top: 0,
      bottom: 0,
      child: PointerInterceptor(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            _roundIcon(
              icon: Icons.tune_rounded,
              tooltip: 'Settings / speed',
              onPressed: () => _openPlaybackSettings(p),
            ),
            const SizedBox(height: 12),
            _roundIcon(
              icon: p.loopOne ? Icons.repeat_one_rounded : Icons.repeat_rounded,
              tooltip: 'Loop',
              onPressed: () => p.toggleLoop(),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildRightRail(BuildContext context, VideoPlayerProvider p) {
    return Positioned(
      right: 12,
      top: 0,
      bottom: 0,
      child: PointerInterceptor(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            _roundIcon(
              icon: Icons.playlist_add_check_rounded,
              tooltip: 'Playlist',
              onPressed: () => _openPlaylist(p),
            ),
            const SizedBox(height: 12),
            _roundIcon(
              icon: Icons.picture_in_picture_alt_rounded,
              tooltip: 'Picture-in-picture',
              onPressed: () => _tryPip(p),
            ),
            const SizedBox(height: 12),
            _roundIcon(
              icon: Icons.brightness_6_rounded,
              tooltip: 'Brightness',
              onPressed: () => _openBrightnessSheet(p),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildBottomChrome(BuildContext context, VideoPlayerProvider p) {
    final c = p.controller;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 12,
      bottom: MediaQuery.paddingOf(context).bottom + 8,
      child: PointerInterceptor(
        child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(c.value.position),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontFeatures: []),
                        ),
                        const Spacer(),
                        Text(
                          _formatDuration(c.value.duration),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: AppColors.roseAccent,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 56,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 52),
                            child: Center(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _roundIcon(
                                      icon: p.touchLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                                      tooltip: 'Touch lock',
                                      onPressed: () => p.toggleTouchLock(),
                                    ),
                                    const SizedBox(width: 6),
                                    _roundIcon(
                                      icon: Icons.replay_10_rounded,
                                      tooltip: 'Back 10 seconds',
                                      onPressed: () => p.skipBack10(),
                                    ),
                                    const SizedBox(width: 6),
                                    Material(
                                      color: AppColors.roseAccent.withValues(alpha: 0.9),
                                      shape: const CircleBorder(),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap: () => p.togglePlayPause(),
                                        child: SizedBox(
                                          width: 56,
                                          height: 56,
                                          child: Icon(
                                            c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 34,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _roundIcon(
                                      icon: Icons.forward_10_rounded,
                                      tooltip: 'Forward 10 seconds',
                                      onPressed: () => p.skipForward10(),
                                    ),
                                    const SizedBox(width: 6),
                                    _roundIcon(
                                      icon: Icons.fit_screen_rounded,
                                      tooltip: 'Fit (cover / contain / fill)',
                                      onPressed: _cycleVideoAspect,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _roundIcon(
                              icon: p.isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                              tooltip: 'Fullscreen',
                              onPressed: () => unawaited(_toggleFullScreen(p)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!p.isFullScreen) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppColors.violetGlow,
                        ),
                        onPressed: _playAudioOnly,
                        icon: const Icon(Icons.headphones_rounded),
                        label: const Text('Play audio only'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
      ),
    );
  }
}

/// Explicit [SizedBox] + [AspectRatio] / [FittedBox] sizing so [VideoPlayer] gets
/// non-zero layout (texture + [Center] under [Transform] could collapse / stay black).
class _VideoFitSurface extends StatelessWidget {
  const _VideoFitSurface({
    required this.controller,
    required this.fit,
  });

  final VideoPlayerController controller;
  final BoxFit fit;

  static Size _displaySize({
    required double maxW,
    required double maxH,
    required double videoAspect,
    required BoxFit fit,
  }) {
    final ar = videoAspect <= 0 ? 16 / 9 : videoAspect;
    final v = maxW / maxH;
    if (fit == BoxFit.cover) {
      if (v > ar) {
        return Size(maxW, maxW / ar);
      }
      return Size(maxH * ar, maxH);
    }
    if (fit == BoxFit.fill) {
      return Size(maxW, maxH);
    }
    if (v > ar) {
      return Size(maxH * ar, maxH);
    }
    return Size(maxW, maxW / ar);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        if (maxW <= 0 || maxH <= 0) {
          return const SizedBox.shrink();
        }
        final ar = controller.value.aspectRatio <= 0 ? 16 / 9 : controller.value.aspectRatio;
        final sz = _displaySize(maxW: maxW, maxH: maxH, videoAspect: ar, fit: fit);

        final Widget videoCore = fit == BoxFit.fill
            ? FittedBox(
                fit: BoxFit.fill,
                child: AspectRatio(
                  aspectRatio: ar,
                  child: VideoPlayer(controller),
                ),
              )
            : AspectRatio(
                aspectRatio: ar,
                child: VideoPlayer(controller),
              );

        return ClipRect(
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: sz.width,
              height: sz.height,
              child: videoCore,
            ),
          ),
        );
      },
    );
  }
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

enum _DragZone { none, left, right }
