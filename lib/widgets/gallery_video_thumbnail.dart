import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// Loads a gallery video frame via [PhotoManager] when [assetId] is set.
class GalleryVideoThumbnail extends StatefulWidget {
  const GalleryVideoThumbnail({
    super.key,
    required this.assetId,
    this.width = 56,
    this.height = 56,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
  });

  final String assetId;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  @override
  State<GalleryVideoThumbnail> createState() => _GalleryVideoThumbnailState();
}

class _GalleryVideoThumbnailState extends State<GalleryVideoThumbnail> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(GalleryVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      _future = _load();
    }
  }

  Future<Uint8List?> _load() async {
    final entity = await AssetEntity.fromId(widget.assetId);
    if (entity == null) return null;
    final w = (widget.width * 2).round().clamp(80, 400);
    final h = (widget.height * 2).round().clamp(80, 400);
    return entity.thumbnailDataWithSize(ThumbnailSize(w, h));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: FutureBuilder<Uint8List?>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data != null && data.isNotEmpty) {
              return Image.memory(
                data,
                fit: widget.fit,
                gaplessPlayback: true,
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ColoredBox(
                color: Colors.white.withValues(alpha: 0.06),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return ColoredBox(
              color: Colors.white.withValues(alpha: 0.08),
              child: Icon(
                Icons.movie_rounded,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            );
          },
        ),
      ),
    );
  }
}
