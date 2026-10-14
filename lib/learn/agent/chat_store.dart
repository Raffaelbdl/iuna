import '../db/learn_repository.dart';
import '../photo/photo.dart';
import 'chat_models.dart';

abstract class ChatStore {
  Future<List<ChatMessage>> load();
  Future<ChatMessage> append(ChatMessage message);

  /// Summary standing in for archived messages, if any.
  Future<String?> summary();

  bool get supportsCompaction;
  Future<void> compact({required ChatMessage through, required String summary});
}

/// The Ask chat: gone as soon as the screen is.
class MemoryChatStore implements ChatStore {
  final List<ChatMessage> _messages = [];
  var _nextId = 1;

  @override
  Future<List<ChatMessage>> load() async => List.of(_messages);

  @override
  Future<ChatMessage> append(ChatMessage message) async {
    final stored = message.copyWith(id: _nextId++);
    _messages.add(stored);
    return stored;
  }

  @override
  Future<String?> summary() async => null;

  @override
  bool get supportsCompaction => false;

  @override
  Future<void> compact({required ChatMessage through, required String summary}) async {}
}

/// A course room or lesson, persisted in `learn.sqlite`.
class SessionChatStore implements ChatStore {
  SessionChatStore(this.repo, this.sessionId);

  final LearnRepository repo;
  final int sessionId;

  @override
  Future<List<ChatMessage>> load() async =>
      [for (final row in await repo.messages(sessionId)) ChatMessage.fromRow(row)];

  @override
  Future<ChatMessage> append(ChatMessage message) async {
    final row = await repo.addMessage(
      sessionId,
      role: message.role,
      content: message.content,
      toolCalls: message.toolCalls.isEmpty
          ? null
          : ChatToolCall.encodeList(message.toolCalls),
      toolCallId: message.toolCallId,
      toolName: message.toolName,
      kind: message.kind,
      attachments:
          message.photos.isEmpty ? null : Photo.encodeList(message.photos),
    );
    // The message as sent, with its row id: decoding the row again would
    // only rebuild the same photos from their base64.
    return message.copyWith(id: row.id, archived: row.archived);
  }

  @override
  Future<String?> summary() async => (await repo.sessionById(sessionId))?.summary;

  @override
  bool get supportsCompaction => true;

  @override
  Future<void> compact({required ChatMessage through, required String summary}) =>
      repo.compactSession(sessionId, throughMessageId: through.id!, summary: summary);
}

