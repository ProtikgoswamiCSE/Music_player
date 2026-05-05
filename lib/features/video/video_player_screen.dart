import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../audio/now_playing_screen.dart';
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
    _controller?.dispose();
    super.dispose();
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
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const NowPlayingScreen()),
    );
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
              child: GestureDetector(
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
                child: ClipRect(
                  child: Transform.scale(
                    scale: _videoScale,
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      child: Builder(
                        builder: (context) {
                          final ar = c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio;
                          final sz = c.value.size;
                          final w = sz.width > 0 ? sz.width : 1920.0;
                          final h = sz.height > 0 ? sz.height : w / ar;
                          return SizedBox(width: w, height: h, child: VideoPlayer(c));
                        },
                      ),
                    ),
                  ),
                ),
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
        ],
      ),
    );
  }
}
