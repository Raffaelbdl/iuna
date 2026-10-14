import '../db/learn_database.dart';
import 'chat_models.dart';

/// Adapted from guu's compact.py (itself from opencode's summarizer).
const String kCompactionPrompt =
    'You are a context summarization agent. You are given a conversation '
    'between a Japanese learner and their tutor, Kuma-sensei. Produce a '
    'structured summary so the same tutor can seamlessly continue the '
    'conversation with only your summary as context.\n\n'
    'Structure: ## Context (what this session is about), ## State (what has '
    'been taught, checked, decided or learned — preserve exact chapter ids, '
    'Japanese examples, answers and verdicts), ## Open (anything unresolved, '
    'promised, or in progress). Prefer terse bullets over paragraphs.\n\n'
    'Do not continue the conversation, do not respond to questions in it, do '
    'not add commentary. Only output the summary. If the conversation ends '
    'with an unanswered question or a request to the learner, preserve it '
    'exactly under ## Open.';

String _clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n)}…';

String compactionTranscript(List<ChatMessage> messages) {
  final lines = <String>[];
  for (final m in messages) {
    final content = m.content.trim();
    switch (m.role) {
      case MessageRole.assistant:
        for (final c in m.toolCalls) {
          lines.add('tutor -> tool ${c.name}(${_clip(c.arguments, 300)})');
        }
        if (content.isNotEmpty) lines.add('tutor: $content');
      case MessageRole.tool:
        lines.add('tool result: ${_clip(content, 400)}');
      case MessageRole.user:
        final photos = m.photos.isEmpty
            ? ''
            : '[attached ${m.photos.length} photo${m.photos.length == 1 ? '' : 's'}] ';
        if (content.isNotEmpty || photos.isNotEmpty) {
          lines.add('learner: $photos$content');
        }
      case MessageRole.note:
        if (content.isNotEmpty) lines.add('app: $content');
    }
  }
  return lines.join('\n');
}
