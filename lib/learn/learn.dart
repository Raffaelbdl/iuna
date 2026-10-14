import '../db/database.dart' show AppDatabase;
import '../db/repository.dart';
import '../db/sqlite_open.dart';
import 'agent/bookmark_tool.dart';
import 'agent/chat_controller.dart';
import 'agent/chat_store.dart';
import 'agent/tools.dart';
import 'db/learn_database.dart';
import 'db/learn_repository.dart';
import 'deck_bookmarks.dart';
import 'learn_backup.dart';
import 'learn_settings.dart';
import 'llm/llm.dart';
import 'llm/model_vision.dart';
import 'llm/openrouter_client.dart';
import 'llm/transcriber.dart';
import 'photo/photo_picker.dart';
import 'voice/dictation.dart';
import 'voice/mic_recorder.dart';

/// Process-wide handle on `learn.sqlite`, opened on first use.
class Learn {
  Learn._();

  static final Learn instance = Learn._();

  LearnRepository? _repo;

  LearnRepository get repo => _repo ??= LearnRepository(LearnDatabase());

  /// The repository only if the learner ever used the tutor — a backup
  /// must not create an empty `learn.sqlite` just to find nothing in it.
  Future<LearnRepository?> existingRepo() async {
    if (_repo != null) return _repo;
    if (await (await documentsFile(kLearnDbFileName)).exists()) return repo;
    return null;
  }

  /// Courses to back up alongside the library, or null when there are
  /// none on this device.
  Future<CourseSnapshots?> snapshots() async {
    final r = await existingRepo();
    return r == null ? null : CourseSnapshots(r);
  }
}

/// What every Learn screen needs, bundled so tests can swap in an
/// in-memory database, a scripted model and a memory key store.
class LearnEnv {
  LearnEnv({
    required this.repo,
    required this.llm,
    LearnSettings? settings,
    this.bookmarks,
    this.dictation,
    this.photos,
    VisionModels? vision,
  })  : settings = settings ?? LearnSettings.instance,
        _vision = vision ?? VisionModels();

  factory LearnEnv.live(AppDatabase deck) {
    final settings = LearnSettings.instance;
    return LearnEnv(
      repo: Learn.instance.repo,
      llm: OpenRouterClient(apiKey: settings.apiKey),
      settings: settings,
      bookmarks: DeckBookmarks(IunaRepository(deck)),
      dictation: Dictation(
        recorder: MicRecorder.new,
        transcriber: OpenRouterTranscriber(apiKey: settings.apiKey),
      ),
      photos: const ImagePickerPhotos(),
    );
  }

  final LearnRepository repo;
  final LlmClient llm;
  final LearnSettings settings;

  /// Where the tutor bookmarks words; without it the tool is left out.
  final WordBookmarks? bookmarks;

  /// Hold-to-speak; without it the composers show no mic.
  final Dictation? dictation;

  /// Where an attached photo comes from; without it the composers show
  /// no paperclip.
  final PhotoPicker? photos;

  final VisionModels _vision;

  Future<String> model() => settings.model();

  /// The model for a turn carrying a photo: the chosen one when it can
  /// read images, else one that can. The default tutor model is
  /// text-only, so most learners' photos go to the fallback.
  Future<String> photoModel() async {
    final id = await settings.model();
    return await _vision.accepts(id) ? id : kPhotoFallbackModel;
  }

  /// A conversation wired to this environment: the learner's model (or
  /// one that reads photos), dictation, and usage booked to [courseId].
  ChatController chat({
    required ChatStore store,
    required Future<String> Function() systemPrompt,
    List<ChatTool> tools = const [],
    String usageKind = 'chat',
    int? courseId,
    Future<String?> Function()? kickoff,
  }) =>
      ChatController(
        llm: llm,
        store: store,
        systemPrompt: systemPrompt,
        model: model,
        photoModel: photoModel,
        tools: tools,
        usageKind: usageKind,
        dictation: dictation,
        kickoff: kickoff,
        onUsage: (u, {required model, required kind}) =>
            recordUsage(u, model: model, kind: kind, courseId: courseId),
      );

  Future<void> recordUsage(
    LlmUsage usage, {
    required String model,
    required String kind,
    int? courseId,
  }) =>
      repo.recordUsage(
        courseId: courseId,
        kind: kind,
        model: model,
        promptTokens: usage.promptTokens,
        completionTokens: usage.completionTokens,
        cost: usage.cost,
      );
}
