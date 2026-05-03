enum MediaKind { audio, video }

class MediaTrack {
  const MediaTrack({
    required this.path,
    required this.title,
    required this.kind,
    this.fromDevice = false,
    this.artist,
    /// Photo library asset id (Android MediaStore / iOS localIdentifier) for gallery-loaded videos.
    this.galleryAssetId,
  });

  final String path;
  final String title;
  final MediaKind kind;

  /// Loaded from MediaStore / Apple Music library scan (not file picker).
  final bool fromDevice;

  final String? artist;

  final String? galleryAssetId;

  MediaTrack copyWith({
    String? path,
    String? title,
    MediaKind? kind,
    bool? fromDevice,
    String? artist,
    String? galleryAssetId,
  }) {
    return MediaTrack(
      path: path ?? this.path,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      fromDevice: fromDevice ?? this.fromDevice,
      artist: artist ?? this.artist,
      galleryAssetId: galleryAssetId ?? this.galleryAssetId,
    );
  }
}
