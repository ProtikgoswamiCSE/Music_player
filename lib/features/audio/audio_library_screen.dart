import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/media_track.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/media_library_provider.dart';
import '../../widgets/glass_card.dart';

String _extractFolderName(String path) {
  final parts = path.split(RegExp(r'[/\\]'));
  if (parts.length < 2) return 'Unknown Folder';
  final name = parts[parts.length - 2].trim();
  return name.isEmpty ? 'Unknown Folder' : name;
}

class AudioLibraryScreen extends StatelessWidget {
  const AudioLibraryScreen({super.key});

  String _subtitle(MediaTrack t) {
    if (!t.fromDevice) return '${_extractFolderName(t.path)} · Added from files';
    if (t.artist != null && t.artist!.isNotEmpty) return t.artist!;
    return '${_extractFolderName(t.path)} · Phone library';
  }

  Widget _buildBody(BuildContext context, MediaLibraryProvider lib, AudioPlayerProvider audio) {
    if (lib.isScanningDeviceMusic && lib.audioTracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.cyanAccent),
            const SizedBox(height: 16),
            Text(
              'Scanning phone music...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    if (lib.audioTracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.queue_music_rounded, size: 48, color: AppColors.cyanAccent.withValues(alpha: 0.9)),
                const SizedBox(height: 16),
                Text(
                  lib.deviceMusicScanMessage != null ? 'Unable to load' : 'No songs found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  lib.deviceMusicScanMessage ??
                      'Device songs appear here automatically. Grant media permission if needed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), height: 1.4),
                ),
                if (lib.deviceMusicScanMessage != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => lib.loadDeviceMusic(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text('Open Settings'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final grouped = <String, List<MediaTrack>>{};
    for (final track in lib.audioTracks) {
      final folder = _extractFolderName(track.path);
      grouped.putIfAbsent(folder, () => <MediaTrack>[]).add(track);
    }

    final folders = grouped.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: folders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final folder = folders[i];
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _AudioFolderTracksScreen(
                folderName: folder.key,
                subtitleBuilder: _subtitle,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.violetGlow.withValues(alpha: 0.85),
                      AppColors.cyanAccent.withValues(alpha: 0.65),
                    ],
                  ),
                ),
                child: const Icon(Icons.folder_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${folder.value.length} tracks',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.5)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<MediaLibraryProvider>();
    final audio = context.watch<AudioPlayerProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Audio Library'),
        actions: [
          IconButton(
            tooltip: 'Refresh phone music',
            onPressed: lib.isScanningDeviceMusic ? null : () => lib.loadDeviceMusic(),
            icon: lib.isScanningDeviceMusic
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          if (audio.currentTrack != null)
            IconButton(
              tooltip: 'Stop',
              onPressed: () => audio.stop(),
              icon: const Icon(Icons.stop_circle_outlined),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lib.deviceMusicScanMessage != null && lib.audioTracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber.shade200, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lib.deviceMusicScanMessage!,
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85), height: 1.35),
                      ),
                    ),
                    TextButton(
                      onPressed: () => lib.loadDeviceMusic(),
                      child: const Text('Fix'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: _buildBody(context, lib, audio)),
        ],
      ),
    );
  }
}

class _AudioFolderTracksScreen extends StatelessWidget {
  const _AudioFolderTracksScreen({
    required this.folderName,
    required this.subtitleBuilder,
  });

  final String folderName;
  final String Function(MediaTrack) subtitleBuilder;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<MediaLibraryProvider>();
    final audio = context.watch<AudioPlayerProvider>();
    final tracks = lib.audioTracks.where((t) => _extractFolderName(t.path) == folderName).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(folderName)),
      body: tracks.isEmpty
          ? Center(
              child: Text(
                'No tracks in this folder',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              itemCount: tracks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = tracks[i];
                final active = audio.currentTrack?.path == t.path;
                return GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: () => context.read<AudioPlayerProvider>().playTrack(t),
                  child: Row(
                    children: [
                      Icon(
                        active ? Icons.equalizer_rounded : Icons.music_note_rounded,
                        color: active ? AppColors.cyanAccent : Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: active ? AppColors.cyanAccent : Colors.white,
                              ),
                            ),
                            Text(
                              subtitleBuilder(t),
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.read<MediaLibraryProvider>().removeAudio(t),
                        icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.45)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
