import '../db/database.dart' show AppDatabase;
import '../db/repository.dart';
import '../db/sqlite_open.dart';
import 'agent/chat_controller.dart';
import 'agent/chat_store.dart';
import 'agent/example_writer.dart';
import 'agent/tools.dart';
import 'agent/tutor_prompt.dart';
import 'db/learn_database.dart';
import 'db/learn_repository.dart';
import 'deck.dart';
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
      vision: _sharedVision,
      bookmarks: DeckBookmarks(IunaRepository(deck)),
      dictation: Dictation(
        recorder: MicRecorder.new,
        transcriber: OpenRouterTranscriber(apiKey: settings.apiKey),
      ),
      photos: const ImagePickerPhotos(),
    );
  }

  /// One per process, so what OpenRouter said about a model holds across
  /// screens.
  static final VisionModels _sharedVision = VisionModels();

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

  /// One call, no chat: example sentences for [card], booked as
  /// `examples`. Fails only with [ExampleWriterError].
  Future<List<ExampleText>> writeExamples(FocusCard card) async =>
      parseWrittenExamples(await _oneShot(
        (await TutorAssets.load()).examples,
        exampleBrief(card),
        kind: 'examples',
      ));

  /// English for the [sentences] of [card], by index; one the model
  /// skipped is absent. Booked as `translate`; fails only with
  /// [ExampleWriterError].
  Future<Map<int, String>> translateExamples(FocusCard card, List<String> sentences) async =>
      parseNumberedEnglish(
        await _oneShot(
          (await TutorAssets.load()).translate,
          translateBrief(card, sentences),
          kind: 'translate',
        ),
        sentences.length,
      );

  Future<String> _oneShot(String system, String user, {required String kind}) async {
    final modelId = await model();
    final LlmTurn turn;
    try {
      turn = await collectTurn(llm.chat(LlmRequest(model: modelId, messages: [
        {'role': 'system', 'content': system.trim()},
        {'role': 'user', 'content': user},
      ])));
    } on LlmException catch (e) {
      throw ExampleWriterError(e.friendly);
    }
    if (turn.usage case final usage?) {
      await recordUsage(usage, model: modelId, kind: kind);
    }
    return turn.text.toString();
  }

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
