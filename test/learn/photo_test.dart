import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iuna/learn/agent/chat_controller.dart';
import 'package:iuna/learn/agent/chat_models.dart';
import 'package:iuna/learn/agent/chat_store.dart';
import 'package:iuna/learn/agent/compaction.dart';
import 'package:iuna/learn/db/learn_database.dart';
import 'package:iuna/learn/db/learn_repository.dart';
import 'package:iuna/learn/learn.dart';
import 'package:iuna/learn/learn_settings.dart';
import 'package:iuna/learn/llm/model_vision.dart';
import 'package:iuna/learn/photo/photo.dart';
import 'package:iuna/learn/photo/photo_picker.dart';

import 'fake_llm.dart';
import 'fake_photos.dart';
import 'test_env.dart';

/// The image part of a wire message, or null when it carries none.
String? imageUrlOf(Map<String, dynamic> message) {
  final content = message['content'];
  if (content is! List) return null;
  for (final part in content) {
    if (part is Map && part['type'] == 'image_url') {
      return ((part['image_url'] as Map)['url'] as String);
    }
  }
  return null;
}

void main() {
  group('the photo itself', () {
    test('survives the round trip through a message row', () {
      final photo = testPhoto();
      final back = Photo.decodeList(Photo.encodeList([photo]));
      expect(back, hasLength(1));
      expect(back.single.bytes, photo.bytes);
      expect(back.single.mime, 'image/png');
      expect(back.single.dataUrl, startsWith('data:image/png;base64,'));
    });

    test('a row that is not a photo list decodes to nothing', () {
      expect(Photo.decodeList(null), isEmpty);
      expect(Photo.decodeList(''), isEmpty);
      expect(Photo.decodeList('not json'), isEmpty);
      expect(Photo.decodeList('[{"mime":"image/png"}]'), isEmpty);
    });

    test('is charged its tokens on the wire, not its bytes', () {
      final message = ChatMessage(
        role: MessageRole.user,
        content: 'what does this say?',
        photos: [testPhoto()],
      );
      expect(message.photos.single.bytes.length, greaterThan(400));
      expect(message.wireSize, lessThan(kPhotoWireChars * 2));
      expect(message.wireSize, greaterThan(kPhotoWireChars));
    });

    test('the type comes from the bytes, not the file name', () {
      expect(sniffImageMime(kTestPhotoBytes), 'image/png');
      expect(sniffImageMime(Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0x00])), 'image/jpeg');
      expect(sniffImageMime(Uint8List.fromList(const [1, 2, 3, 4])), isNull);
    });
  });

  group('a chat with a photo in it', () {
    late LearnDatabase db;
    late LearnRepository repo;
    late CourseRow course;

    setUp(() async {
      db = LearnDatabase.forTesting(NativeDatabase.memory());
      repo = LearnRepository(db);
      course = await repo.createCourse(title: 'Reading signs', goal: 'read what I photograph');
    });

    tearDown(() async {
      await repo.dispose();
      await db.close();
    });

    Future<(ChatController, FakeLlm, int)> make(List<Object> script) async {
      final session = await repo.openSession(course.id, kRoomSessionKey);
      final llm = FakeLlm(script);
      final c = ChatController(
        llm: llm,
        store: SessionChatStore(repo, session.id),
        systemPrompt: () async => 'SYSTEM',
        model: () async => 'text/only',
        photoModel: () async => 'reads/images',
      );
      await c.open();
      return (c, llm, session.id);
    }

    test('goes to the model that can read one, as an image part', () async {
      final (c, llm, _) = await make([say('It says 非常口 — emergency exit.')]);
      await c.send('what does this say?', photo: testPhoto());

      final sent = llm.requests.single;
      expect(sent.model, 'reads/images');
      final last = sent.messages.last;
      expect(last['role'], 'user');
      expect((last['content'] as List).first, {'type': 'text', 'text': 'what does this say?'});
      expect(imageUrlOf(last), startsWith('data:image/png;base64,'));
      expect(
        base64Decode(imageUrlOf(last)!.split(',').last),
        kTestPhotoBytes,
      );
    });

    test('a photo with nothing typed is still a message', () async {
      final (c, llm, _) = await make([say('A menu. The first line reads 定食（ていしょく）.')]);
      await c.send('', photo: testPhoto());

      expect(c.messages.first.role, MessageRole.user);
      expect(c.messages.first.content, isEmpty);
      final content = llm.requests.single.messages.last['content'] as List;
      expect(content, hasLength(1));
      expect(content.single['type'], 'image_url');
    });

    test('keeps the reading model for the rest of the session', () async {
      final (c, llm, _) = await make([say('非常口 — emergency exit.'), say('Yes, 出口 is “exit”.')]);
      await c.send('what does this say?', photo: testPhoto());
      await c.send('and 出口?');

      expect(llm.requests.map((r) => r.model), ['reads/images', 'reads/images']);
      // The photo stays in the history, so the second turn carries it too.
      expect(imageUrlOf(llm.requests.last.messages[1]), isNotNull);
    });

    test('a session with no photo stays on the ordinary model', () async {
      final (c, llm, _) = await make([say('もちろん！')]);
      await c.send('teach me signs');
      expect(llm.requests.single.model, 'text/only');
    });

    test('the photo comes back with the messages after a reopen', () async {
      final (c, _, sessionId) = await make([say('非常口 — emergency exit.')]);
      await c.send('what does this say?', photo: testPhoto());

      final reopened = ChatController(
        llm: FakeLlm([]),
        store: SessionChatStore(repo, sessionId),
        systemPrompt: () async => 'SYSTEM',
        model: () async => 'text/only',
      );
      await reopened.open();
      expect(reopened.messages.first.photos.single.bytes, kTestPhotoBytes);
      reopened.dispose();
      c.dispose();
    });

    test('a compacted transcript says a photo was there', () {
      final line = compactionTranscript([
        ChatMessage(role: MessageRole.user, content: 'what is this?', photos: [testPhoto()]),
      ]);
      expect(line, 'learner: [attached 1 photo] what is this?');
    });
  });

  group('which model reads a photo', () {
    MockClient answering(String body, {int status = 200}) => MockClient((req) async {
          expect(req.url.path, contains('/endpoints'));
          return http.Response(body, status);
        });

    String modalities(List<String> input) => jsonEncode({
          'data': {
            'architecture': {'input_modalities': input},
          },
        });

    test('a model that takes images is used as it is', () async {
      final env = _env(VisionModels(client: answering(modalities(['text', 'image']))));
      await env.settings.setModel('some/vision-model');
      expect(await env.photoModel(), 'some/vision-model');
    });

    test('a text-only model hands the photo to the fallback', () async {
      final env = _env(VisionModels(client: answering(modalities(['text']))));
      expect(await env.settings.model(), kDefaultLearnModel);
      expect(await env.photoModel(), kPhotoFallbackModel);
    });

    test('a model that cannot be checked hands it over too', () async {
      final env = _env(VisionModels(client: answering('nope', status: 404)));
      expect(await env.photoModel(), kPhotoFallbackModel);
    });

    test('is asked once per model', () async {
      var calls = 0;
      final vision = VisionModels(client: MockClient((req) async {
        calls++;
        return http.Response(modalities(const ['text', 'image']), 200);
      }));
      expect(await vision.accepts('a/model'), isTrue);
      expect(await vision.accepts('a/model:free'), isTrue);
      expect(calls, 1);
    });
  });
}

LearnEnv _env(VisionModels vision) => testLearnEnv(
      FakeLlm([]),
      settings: LearnSettings(MemorySecretStore()),
      vision: vision,
      photos: FakePhotoPicker(),
    );
