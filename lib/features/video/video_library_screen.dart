import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/media_track.dart';
import '../../providers/media_library_provider.dart';
import '../../widgets/gallery_video_thumbnail.dart';
import '../../widgets/glass_card.dart';
import 'video_player_screen.dart';

String? _firstGalleryAssetId(Iterable<MediaTrack> tracks) {
  for (final t in tracks) {
    final id = t.galleryAssetId;
    if (id != null && id.isNotEmpty) return id;
  }
  return null;
}

String _extractFolderName(String path) {
  final parts = path.split(RegExp(r'[/\\]'));
  if (parts.length < 2) return 'Unknown Folder';
  final name = parts[parts.length - 2].trim();
  return name.isEmpty ? 'Unknown Folder' : name;
}

class VideoLibraryScreen extends StatelessWidget {
  const VideoLibraryScreen({super.key});

  String _subtitle(MediaTrack t) {
    if (!t.fromDevice) return '${_extractFolderName(t.path)} · Added from files';
    return '${_extractFolderName(t.path)} · Gallery · Phone';
  }

  Widget _buildBody(BuildContext context, MediaLibraryProvider lib) {
    if (lib.isScanningDeviceVideos && lib.videoTracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.roseAccent),
            const SizedBox(height: 16),
            Text(
              'Loading gallery videos...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    if (lib.videoTracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.movie_filter_rounded, size: 48, color: AppColors.roseAccent.withValues(alpha: 0.9)),
                const SizedBox(height: 16),
                Text(
                  lib.deviceVideoScanMessage != null ? 'Unable to load' : 'No videos found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  lib.deviceVideoScanMessage ??
                      'Device videos appear here automatically. Grant media permission if needed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), height: 1.4),
                ),
                if (lib.deviceVideoScanMessage != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => lib.loadDeviceVideos(),
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
    for (final track in lib.videoTracks) {
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
              builder: (_) => _VideoFolderTracksScreen(
                folderName: folder.key,
                subtitleBuilder: _subtitle,
              ),
            ),
          ),
          child: Row(
            children: [
              Builder(
                builder: (_) {
                  final previewId = _firstGalleryAssetId(folder.value);
                  if (previewId != null) {
                    return GalleryVideoThumbnail(
                      assetId: previewId,
                      width: 48,
                      height: 48,
                      borderRadius: 14,
                    );
                  }
                  return Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.roseAccent.withValues(alpha: 0.75),
                          AppColors.violetGlow.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                    child: const Icon(Icons.folder_rounded, color: Colors.white),
                  );
                },
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
                      '${folder.value.length} videos',
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Video Library'),
        actions: [
          IconButton(
            tooltip: 'Refresh gallery videos',
            onPressed: lib.isScanningDeviceVideos ? null : () => lib.loadDeviceVideos(),
            icon: lib.isScanningDeviceVideos
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lib.deviceVideoScanMessage != null && lib.videoTracks.isNotEmpty)
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
                        lib.deviceVideoScanMessage!,
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85), height: 1.35),
                      ),
                    ),
                    TextButton(
                      onPressed: () => lib.loadDeviceVideos(),
                      child: const Text('Fix'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: _buildBody(context, lib)),
        ],
      ),
    );
  }
}

class _VideoFolderTracksScreen extends StatelessWidget {
  const _VideoFolderTracksScreen({
    required this.folderName,
    required this.subtitleBuilder,
  });

  final String folderName;
  final String Function(MediaTrack) subtitleBuilder;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<MediaLibraryProvider>();
    final tracks = lib.videoTracks.where((t) => _extractFolderName(t.path) == folderName).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(folderName)),
      body: tracks.isEmpty
          ? Center(
              child: Text(
                'No videos in this folder',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              itemCount: tracks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = tracks[i];
                return GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VideoPlayerScreen(track: t),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Builder(
                        builder: (_) {
                          final id = t.galleryAssetId;
                          if (id != null && id.isNotEmpty) {
                            return GalleryVideoThumbnail(assetId: id, width: 56, height: 56, borderRadius: 12);
                          }
                          return Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.roseAccent.withValues(alpha: 0.55),
                                  AppColors.violetGlow.withValues(alpha: 0.45),
                                ],
                              ),
                            ),
                            child: Icon(Icons.play_circle_fill_rounded, color: Colors.white.withValues(alpha: 0.95)),
                          );
                        },
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
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              subtitleBuilder(t),
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.read<MediaLibraryProvider>().removeVideo(t),
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
