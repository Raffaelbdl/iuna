import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/learn/agent/bookmark_tool.dart';
import 'package:iuna/learn/db/learn_database.dart';
import 'package:iuna/learn/db/learn_repository.dart';
import 'package:iuna/learn/learn.dart';
import 'package:iuna/learn/learn_settings.dart';
import 'package:iuna/learn/llm/llm.dart';
import 'package:iuna/learn/llm/model_vision.dart';
import 'package:iuna/learn/photo/photo_picker.dart';
import 'package:iuna/learn/voice/dictation.dart';

/// A [LearnEnv] over an in-memory `learn.sqlite`, closed when the test
/// ends.
LearnEnv testLearnEnv(
  LlmClient llm, {
  LearnSettings? settings,
  WordBookmarks? bookmarks,
  Dictation? dictation,
  PhotoPicker? photos,
  VisionModels? vision,
}) {
  final db = LearnDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final repo = LearnRepository(db);
  addTearDown(repo.dispose);
  return LearnEnv(
    repo: repo,
    llm: llm,
    settings: settings,
    bookmarks: bookmarks,
    dictation: dictation,
    photos: photos,
    vision: vision,
  );
}
