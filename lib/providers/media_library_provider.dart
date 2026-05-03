import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_track.dart';

class MediaLibraryProvider extends ChangeNotifier {
  final List<MediaTrack> _audioTracks = [];
  final List<MediaTrack> _videoTracks = [];

  List<MediaTrack> get audioTracks => List.unmodifiable(_audioTracks);
  List<MediaTrack> get videoTracks => List.unmodifiable(_videoTracks);

  bool isScanningDeviceMusic = false;
  String? deviceMusicScanMessage;

  bool isScanningDeviceVideos = false;
  String? deviceVideoScanMessage;

  Future<void> _primeAndroidMediaPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Permission.audio.request();
      await Permission.videos.request();
    } catch (e, st) {
      debugPrint('permission prime: $e\n$st');
    }
  }

  /// Loads all songs from the phone library (Android MediaStore / iOS).
  Future<void> loadDeviceMusic() async {
    if (kIsWeb) {
      deviceMusicScanMessage = 'ওয়েবে ডিভাইসের গান তালিকা দেখানো যায় না।';
      notifyListeners();
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      deviceMusicScanMessage = null;
      notifyListeners();
      return;
    }

    if (isScanningDeviceMusic) return;

    isScanningDeviceMusic = true;
    deviceMusicScanMessage = null;
    notifyListeners();

    try {
      await _primeAndroidMediaPermissions();

      final query = OnAudioQuery();
      final allowed = await query.checkAndRequest();
      if (!allowed) {
        deviceMusicScanMessage =
            'মিউজিক লাইব্রেরি অ্যাক্সেসের অনুমতি দিন (সেটিংস → অ্যাপ → Music Player → অনুমতি)। পিক্সেলে “Music and audio” অন করে রিফ্রেশ করুন।';
        return;
      }

      final songs = await query.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      _audioTracks.removeWhere((t) => t.fromDevice);

      final seen = <String>{};
      for (final s in songs) {
        if (s.isRingtone == true || s.isAlarm == true || s.isNotification == true) {
          continue;
        }
        final path = s.data.isNotEmpty ? s.data : (s.uri ?? '');
        if (path.isEmpty || seen.contains(path)) continue;
        seen.add(path);

        final title = s.title.trim().isNotEmpty ? s.title : s.displayNameWOExt;
        final artist = s.artist?.trim();
        _audioTracks.add(
          MediaTrack(
            path: path,
            title: title,
            kind: MediaKind.audio,
            fromDevice: true,
            artist: artist != null && artist.isNotEmpty ? artist : null,
          ),
        );
      }

      deviceMusicScanMessage = null;
    } catch (e, st) {
      debugPrint('loadDeviceMusic failed: $e\n$st');
      deviceMusicScanMessage = 'গান লোড করা যায়নি। আবার চেষ্টা করুন।';
    } finally {
      isScanningDeviceMusic = false;
      notifyListeners();
    }
  }

  /// Gallery / Photos videos (Android + iOS).
  Future<void> loadDeviceVideos() async {
    if (kIsWeb) {
      deviceVideoScanMessage = 'ওয়েবে ডিভাইসের ভিডিও তালিকা দেখানো যায় না।';
      notifyListeners();
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      deviceVideoScanMessage = null;
      notifyListeners();
      return;
    }

    if (isScanningDeviceVideos) return;

    isScanningDeviceVideos = true;
    deviceVideoScanMessage = null;
    notifyListeners();

    try {
      await _primeAndroidMediaPermissions();

      final pmState = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.video,
            mediaLocation: false,
          ),
        ),
      );

      if (!pmState.hasAccess) {
        deviceVideoScanMessage =
            'ভিডিও দেখতে ফটো/ভিডিও লাইব্রেরির অনুমতি দিন। পিক্সেলে সেটিংস থেকে পুরো বা আংশিক অ্যাক্সেস দিন, তারপর রিফ্রেশ।';
        return;
      }

      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: true,
      );

      _videoTracks.removeWhere((t) => t.fromDevice);

      if (paths.isEmpty) {
        deviceVideoScanMessage = null;
        return;
      }

      final root = paths.first;
      final total = await root.assetCountAsync;
      final seen = <String>{};
      const pageSize = 80;

      for (var start = 0; start < total; start += pageSize) {
        final end = math.min(start + pageSize, total);
        final batch = await root.getAssetListRange(start: start, end: end);
        for (final a in batch) {
          if (a.type != AssetType.video) continue;
          final f = await a.file;
          if (f == null) continue;
          final path = f.path;
          if (path.isEmpty || seen.contains(path)) continue;
          seen.add(path);

          var title = a.title;
          if (title == null || title.trim().isEmpty) {
            title = await a.titleAsync;
          }
          if (title.trim().isEmpty) {
            title = path.split(RegExp(r'[/\\]')).last;
          }

          _videoTracks.add(
            MediaTrack(
              path: path,
              title: title.trim(),
              kind: MediaKind.video,
              fromDevice: true,
              galleryAssetId: a.id,
            ),
          );
        }
      }

      deviceVideoScanMessage = null;
    } catch (e, st) {
      debugPrint('loadDeviceVideos failed: $e\n$st');
      deviceVideoScanMessage = 'ভিডিও লোড করা যায়নি। আবার চেষ্টা করুন।';
    } finally {
      isScanningDeviceVideos = false;
      notifyListeners();
    }
  }

  void addAudio(MediaTrack track) {
    _audioTracks.removeWhere((t) => t.path == track.path);
    _audioTracks.insert(0, track);
    notifyListeners();
  }

  void addVideo(MediaTrack track) {
    _videoTracks.removeWhere((t) => t.path == track.path);
    _videoTracks.insert(0, track);
    notifyListeners();
  }

  void removeAudio(MediaTrack track) {
    _audioTracks.removeWhere((t) => t.path == track.path);
    notifyListeners();
  }

  void removeVideo(MediaTrack track) {
    _videoTracks.removeWhere((t) => t.path == track.path);
    notifyListeners();
  }
}
