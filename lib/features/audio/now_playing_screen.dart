import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/media_library_provider.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }

  Widget _buildVolumeControls(AudioPlayerProvider audio) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Volume down',
          style: IconButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(30, 30),
            padding: const EdgeInsets.all(4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => audio.setVolume(audio.volume - 0.1),
          icon: const Icon(Icons.volume_down_rounded, size: 16),
        ),
        Expanded(
          child: Slider(
            value: audio.volume.clamp(0.0, 1.0),
            onChanged: audio.setVolume,
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Volume up',
          style: IconButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(30, 30),
            padding: const EdgeInsets.all(4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => audio.setVolume(audio.volume + 0.1),
          icon: const Icon(Icons.volume_up_rounded, size: 16),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final audio = context.watch<AudioPlayerProvider>();
    final lib = context.watch<MediaLibraryProvider>();
    final track = audio.currentTrack;
    if (track == null) {
      return PopScope(
        onPopInvokedWithResult: (_, _) {},
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No song is playing',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 16),
                  _buildVolumeControls(audio),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final total = audio.duration ?? Duration.zero;
    final pos = audio.position;
    final progress = total.inMilliseconds > 0
        ? (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final tracks = lib.audioTracks;
    final currentIndex = tracks.indexWhere((t) => t.path == track.path);
    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex >= 0 && currentIndex < tracks.length - 1;

    return PopScope(
      onPopInvokedWithResult: (_, _) {},
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  const Spacer(),
                  const Text(
                    'Now Playing',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: 'Close song',
                    onPressed: () async {
                      await context.read<AudioPlayerProvider>().stop();
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.violetGlow.withValues(alpha: 0.95),
                      AppColors.cyanAccent.withValues(alpha: 0.65),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.violetGlow.withValues(alpha: 0.35),
                      blurRadius: 34,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.music_note_rounded, size: 130, color: Colors.white),
              ),
              const SizedBox(height: 34),
              Text(
                track.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                audio.isPlaying ? 'Playing' : 'Paused',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 28),
              Slider(
                value: progress,
                onChanged: (v) {
                  final ms = (v * total.inMilliseconds).round();
                  audio.seek(Duration(milliseconds: ms));
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(pos), style: TextStyle(color: Colors.white.withValues(alpha: 0.65))),
                  Text(_fmt(total), style: TextStyle(color: Colors.white.withValues(alpha: 0.65))),
                ],
              ),
              const SizedBox(height: 16),
              _buildVolumeControls(audio),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    onPressed: hasPrevious
                        ? () => audio.playTrack(tracks[currentIndex - 1])
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  const SizedBox(width: 14),
                  IconButton.filled(
                    onPressed: () => audio.seek(Duration.zero),
                    icon: const Icon(Icons.replay_10_rounded),
                  ),
                  const SizedBox(width: 14),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.violetGlow,
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: () => audio.isPlaying ? audio.pause() : audio.resume(),
                    icon: Icon(audio.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  ),
                  const SizedBox(width: 14),
                  IconButton.filled(
                    onPressed: () {
                      final forward = pos + const Duration(seconds: 10);
                      audio.seek(forward < total ? forward : total);
                    },
                    icon: const Icon(Icons.forward_10_rounded),
                  ),
                  const SizedBox(width: 14),
                  IconButton.filled(
                    onPressed: hasNext
                        ? () => audio.playTrack(tracks[currentIndex + 1])
                        : null,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
            const Spacer(),
          ],
        ),
      ),
      ),
    );
  }
}
