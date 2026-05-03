import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

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
  bool _isFullScreen = false;
  bool _showOverlayControls = true;

  Future<void> _syncSystemUiMode() async {
    if (_isFullScreen || !_showOverlayControls) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSystemUiMode());
    final ctrl = VideoPlayerController.file(File(widget.track.path));
    _controller = ctrl;
    ctrl.addListener(() {
      if (mounted) setState(() {});
    });
    ctrl.initialize().then((_) {
      if (mounted) {
        setState(() {});
        ctrl.play();
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    await context.read<AudioPlayerProvider>().playTrack(widget.track);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      extendBodyBehindAppBar: true,
      appBar: _isFullScreen
          ? null
          : (_showOverlayControls
              ? AppBar(
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: Text(
                    widget.track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : null),
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
                child: _isFullScreen
                    ? ClipRect(
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
                      )
                    : Center(
                        child: AspectRatio(
                          aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                          child: VideoPlayer(c),
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
          if (_isFullScreen && _showOverlayControls)
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
