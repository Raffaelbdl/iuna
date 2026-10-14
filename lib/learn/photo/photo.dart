import 'dart:convert';
import 'dart:typed_data';

/// A photo the learner attached to a message. The bytes travel inside
/// the message row (base64), so a Drive snapshot carries them, deleting
/// a course takes its photos with it, and the Ask chat's photos die with
/// the chat like everything else in it.
class Photo {
  Photo({required Uint8List bytes, this.mime = 'image/jpeg'}) : _bytes = bytes;

  /// A photo as its row stores it. Decoded only when something shows it:
  /// the wire and the database both want the base64 back.
  Photo._stored(String base64, this.mime) : _base64 = base64;

  final String mime;
  Uint8List? _bytes;
  String? _base64;

  Uint8List get bytes => _bytes ??= base64Decode(_base64!);
  String get base64 => _base64 ??= base64Encode(_bytes!);

  /// What OpenRouter wants in an `image_url` part.
  String get dataUrl => 'data:$mime;base64,$base64';

  Map<String, dynamic> toJson() => {'mime': mime, 'data': base64};

  static String encodeList(List<Photo> photos) =>
      jsonEncode([for (final p in photos) p.toJson()]);

  static List<Photo> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final p in list)
          if (p is Map && p['data'] is String)
            Photo._stored(
              p['data'] as String,
              p['mime'] is String ? p['mime'] as String : 'image/jpeg',
            ),
      ];
    } on FormatException {
      // A row written by something that is not this app, or truncated.
      return const [];
    }
  }
}

/// What one photo is charged when the controller decides a session has
/// grown too big to keep sending whole. Its base64 length says nothing
/// useful: a 1024 px photo costs the model on the order of a thousand
/// tokens however many bytes it took.
const int kPhotoWireChars = 4000;
