import 'package:flutter/material.dart';

import '../../theme/iuna_theme.dart';
import '../photo/photo.dart';

/// The attached photo above the composer, with the cross that drops it.
class PhotoAttachmentStrip extends StatelessWidget {
  const PhotoAttachmentStrip({super.key, required this.photo, required this.onRemove});

  final Photo photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 8, 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(IunaRadii.sm),
            child: Image.memory(
              photo.bytes,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Photo attached',
              style: TextStyle(fontSize: 12, color: IunaPalette.ink3),
            ),
          ),
          IconButton(
            tooltip: 'Remove photo',
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18, color: IunaPalette.ink3),
          ),
        ],
      ),
    );
  }
}

/// A sent photo inside its bubble. Tapping it opens it big enough to
/// read, which is the whole point of having sent it.
class PhotoBubbleImage extends StatelessWidget {
  const PhotoBubbleImage({super.key, required this.photo});

  final Photo photo;

  static const _maxHeight = 260.0;

  @override
  Widget build(BuildContext context) {
    // Decoded no bigger than the bubble can show it (its widest is 80% of
    // the screen): a full 1280 px photo per bubble fills the image cache
    // after a handful. The viewer decodes the original.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = ResizeImage(
      MemoryImage(photo.bytes),
      width: (MediaQuery.sizeOf(context).width * 0.8 * dpr).round(),
      height: (_maxHeight * dpr).round(),
      policy: ResizeImagePolicy.fit,
      allowUpscaling: false,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(PageRouteBuilder<void>(
          opaque: false,
          barrierColor: Colors.black87,
          pageBuilder: (_, _, _) => _PhotoViewer(photo: photo),
        )),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(IunaRadii.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxHeight),
            child: Image(image: image, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo});

  final Photo photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                maxScale: 6,
                child: Center(child: Image.memory(photo.bytes)),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            right: 4,
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
