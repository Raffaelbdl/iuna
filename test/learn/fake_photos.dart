import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iuna/learn/llm/model_vision.dart';
import 'package:iuna/learn/photo/photo.dart';
import 'package:iuna/learn/photo/photo_picker.dart';

/// A photographed page: cream paper with lines of text on it. Small, but
/// a real PNG, so `Image.memory` decodes it in a widget test.
final Uint8List kTestPhotoBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAPAAAAC0CAIAAAAl/ja/AAABwElEQVR42u3dMRGAMAxA0cjpyFwB'
  '6EAGYtHA2Jm1AliSvLunoPe3XNK4rxPKCE+AoEHQIGgQNILerPeBFASNoEHQIGgQNIIWNIIGQYOg'
  'QdAIWtAIGgQNggZBI2hBI2ioGvQ8BvxO0Aha0Aha0AgaBI2gBY2gBY2gBU3JoMHoGwQNgkbQXgpB'
  'g6BB0CBoBA2CBkGDoEHQCBoEDYIGl5OwsSJoBC1oBA2CBkEjaEEjaEEjaHA5CQSNoAWNoEHQIGgQ'
  'NIIWNIIGQYOgQdAIWtAIGgQNggZBI2gbK3ZDBI2gBY2gBY2gBY2gBS1oQSNoQSNoQSNok0JMCkHQ'
  'IGgQNIIWNIIGQYOgQdAIWtAIGgQNggZBI2hBI2iwsQI+r0fQgkbQgkbQgkbQIGgELWgELWg6Bw1G'
  '3yBoEDSC9lIIGgQNggZBI2gQNAgaBA2CRtAgaBA0uJyEjRVBI2hBI2gQNAgaQQsaQQsaQYPLSSBo'
  'BC1oBA2CBkGDoBG0oBE0CBoEDYJG0IJG0CBoEDQIGkGDoEHQIGgQNIIGQYOgQdAIWtAIGgQNggZB'
  'I2hBI2gQNAgaBI2gBU35oCEvQSNoEDQIGgRNYx8egB6FH3wALwAAAABJRU5ErkJggg==',
);

Photo testPhoto() => Photo(bytes: kTestPhotoBytes, mime: 'image/png');

/// A picker that hands back [photo] for whichever source it is asked,
/// or nothing when the learner backs out.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({Photo? photo}) : photo = photo ?? testPhoto();

  Photo? photo;
  final asked = <PhotoSource>[];

  @override
  Future<Photo?> pick(PhotoSource source) async {
    asked.add(source);
    return photo;
  }
}

/// Every model reads as text-only, so a photo goes to the fallback and
/// no test has to touch the network to find that out.
VisionModels textOnlyVisionModels() => VisionModels(
      client: MockClient((req) async => http.Response(
            jsonEncode({
              'data': {
                'architecture': {
                  'input_modalities': ['text'],
                },
              },
            }),
            200,
          )),
    );
