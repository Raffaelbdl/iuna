import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'photo.dart';

enum PhotoSource { camera, gallery }

abstract class PhotoPicker {
  /// The photo the learner chose, or null when they backed out.
  Future<Photo?> pick(PhotoSource source);
}

/// The camera and the system photo picker, downscaled on the way in:
/// a phone camera's 12 MP original would cost far more than the model
/// can even look at, and every copy of it lands in a Drive snapshot.
class ImagePickerPhotos implements PhotoPicker {
  const ImagePickerPhotos({this.longEdge = 1280, this.quality = 80});

  /// Longest side kept, in pixels. Enough to read a textbook page.
  final double longEdge;
  final int quality;

  @override
  Future<Photo?> pick(PhotoSource source) async {
    final file = await ImagePicker().pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: longEdge,
      maxHeight: longEdge,
      imageQuality: quality,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return Photo(bytes: bytes, mime: sniffImageMime(bytes) ?? file.mimeType ?? 'image/jpeg');
  }
}

/// The type from the bytes themselves: the picker re-encodes what it
/// downscales, so the file name it hands back can be a lie.
String? sniffImageMime(Uint8List bytes) {
  bool starts(List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  if (starts(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (starts(const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (starts(const [0x47, 0x49, 0x46])) return 'image/gif';
  if (bytes.length > 12 && starts(const [0x52, 0x49, 0x46, 0x46]) &&
      bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}
