import 'dart:convert';

import '../db/learn_database.dart';
import '../photo/photo.dart';

class ChatToolCall {
  ChatToolCall({required this.id, required this.name, required this.arguments});

  final String id;
  final String name;

  /// Raw JSON text as the model produced it.
  final String arguments;

  /// Parsed arguments, or null when the model sent something that is not
  /// a JSON object. Decoded once: the chat view reads it on every rebuild,
  /// and a `course_write` or `save_state` call carries whole documents.
  late final Map<String, dynamic>? args = _decodeArgs();

  Map<String, dynamic>? _decodeArgs() {
    try {
      final decoded = jsonDecode(arguments.trim().isEmpty ? '{}' : arguments);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'arguments': arguments};

  Map<String, dynamic> toApi() => {
        'id': id,
        'type': 'function',
        'function': {
          'name': name,
          'arguments': arguments.trim().isEmpty ? '{}' : arguments,
        },
      };

  static String encodeList(List<ChatToolCall> calls) =>
      jsonEncode([for (final c in calls) c.toJson()]);

  static List<ChatToolCall> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final c in list)
          if (c is Map)
            ChatToolCall(
              id: '${c['id'] ?? ''}',
              name: '${c['name'] ?? ''}',
              arguments: '${c['arguments'] ?? ''}',
            ),
      ];
    } on FormatException {
      return const [];
    }
  }
}

class ChatMessage {
  const ChatMessage({
    this.id,
    required this.role,
    this.content = '',
    this.toolCalls = const [],
    this.toolCallId,
    this.toolName,
    this.kind,
    this.photos = const [],
    this.archived = false,
  });

  factory ChatMessage.fromRow(MessageRow row) => ChatMessage(
        id: row.id,
        role: row.role,
        content: row.content,
        toolCalls: ChatToolCall.decodeList(row.toolCalls),
        toolCallId: row.toolCallId,
        toolName: row.toolName,
        kind: row.kind,
        photos: Photo.decodeList(row.attachments),
        archived: row.archived,
      );

  final int? id;
  final MessageRole role;
  final String content;
  final List<ChatToolCall> toolCalls;
  final String? toolCallId;
  final String? toolName;

  /// On a note: what it is for (the kickoff, a wrap-up), so the view can
  /// caption it without reading its text.
  final String? kind;

  /// Photos the learner attached. Only their own messages carry any.
  final List<Photo> photos;
  final bool archived;

  ChatMessage copyWith({int? id, bool? archived}) => ChatMessage(
        id: id ?? this.id,
        role: role,
        content: content,
        toolCalls: toolCalls,
        toolCallId: toolCallId,
        toolName: toolName,
        kind: kind,
        photos: photos,
        archived: archived ?? this.archived,
      );

  Map<String, dynamic> toApi({List<Map<String, dynamic>>? reasoning}) {
    switch (role) {
      case MessageRole.user:
      case MessageRole.note:
        if (photos.isEmpty) return {'role': 'user', 'content': content};
        return {
          'role': 'user',
          'content': [
            if (content.isNotEmpty) {'type': 'text', 'text': content},
            for (final p in photos)
              {
                'type': 'image_url',
                'image_url': {'url': p.dataUrl},
              },
          ],
        };
      case MessageRole.assistant:
        return {
          'role': 'assistant',
          'content': toolCalls.isNotEmpty && content.isEmpty ? null : content,
          if (toolCalls.isNotEmpty)
            'tool_calls': [for (final c in toolCalls) c.toApi()],
          if (reasoning != null && reasoning.isNotEmpty)
            'reasoning_details': reasoning,
        };
      case MessageRole.tool:
        return {
          'role': 'tool',
          'tool_call_id': toolCallId ?? '',
          'content': content,
        };
    }
  }

  /// Roughly what this message takes up on the wire, for deciding when a
  /// session has grown too big. A photo is charged [kPhotoWireChars]
  /// rather than its base64 length: what it costs is its tokens, and
  /// measuring its bytes would compact the session after every photo.
  int get wireSize {
    var n = content.length + 24;
    for (final c in toolCalls) {
      n += c.name.length + c.arguments.length + 48;
    }
    return n + photos.length * kPhotoWireChars;
  }
}
