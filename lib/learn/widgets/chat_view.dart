import 'package:flutter/material.dart';

import '../../theme/iuna_theme.dart';
import '../agent/chat_controller.dart';
import '../agent/chat_models.dart';
import '../agent/choices.dart';
import '../agent/tools.dart';
import '../db/learn_database.dart';
import '../photo/photo.dart';
import '../photo/photo_picker.dart';
import '../voice/dictation.dart';
import 'chat_composer.dart';
import 'choice_buttons.dart';
import 'photo_attachment.dart';
import 'quiz_card.dart';
import 'tutor_markdown.dart';
import 'waveform.dart';

/// A conversation with Kuma-sensei: bubbles, tool activity, the live quiz
/// card, a dictated clip on its way to text, and the composer.
class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.controller,
    this.empty,
    this.onActivityTap,
    this.noteCaptions = const {},
    this.hint = 'Message Kuma-sensei…',
    this.picker,
  });

  final ChatController controller;

  /// Shown instead of the list while there is nothing to show.
  final Widget? empty;

  /// A tap on a tool's history chip, when that chip is tappable.
  final ValueChanged<ChatTool>? onActivityTap;

  /// Caption shown for an app note, by [ChatMessage.kind].
  final Map<String, String> noteCaptions;
  final String hint;

  /// Photo attachments, when the app can pick one.
  final PhotoPicker? picker;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _input = TextEditingController();
  Photo? _photo;

  // A stored tool result never changes, so its history entry is built
  // once; replies and the live question only move when messages do.
  final _toolEntries = <String, (ChatMessage, Widget?)>{};
  List<ChatMessage>? _scanned;
  List<String?> _replies = const [];
  int _question = -1;

  @override
  void didUpdateWidget(ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        (oldWidget.onActivityTap == null) != (widget.onActivityTap == null)) {
      _toolEntries.clear();
      _scanned = null;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    final photo = _photo;
    if (text.trim().isEmpty && photo == null) return;
    _input.clear();
    setState(() => _photo = null);
    widget.controller.send(text, photo: photo);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final items = _items(c);
        final Widget body;
        if (!c.loaded) {
          body = const Center(child: CircularProgressIndicator());
        } else if (items.isEmpty && widget.empty != null) {
          body = widget.empty!;
        } else {
          body = ListView.builder(
            reverse: true,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            itemCount: items.length,
            itemBuilder: (_, i) => items[items.length - 1 - i],
          );
        }
        return Column(
          children: [
            Expanded(child: body),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: ChatComposer(
                  controller: _input,
                  hint: c.pendingQuiz != null ? 'Answer the card above first' : widget.hint,
                  enabled: c.loaded && c.pendingQuiz == null && c.pendingVoice == null,
                  busy: c.busy,
                  onSend: _send,
                  onStop: c.cancel,
                  recorder: c.dictation?.recorder,
                  onVoice: c.dictate,
                  picker: widget.picker,
                  photo: _photo,
                  onPhoto: widget.picker == null
                      ? null
                      : (photo) => setState(() => _photo = photo),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _items(ChatController c) {
    final messages = c.messages;
    final results = <String, ChatMessage>{
      for (final m in messages)
        if (m.role == MessageRole.tool && m.toolCallId != null) m.toolCallId!: m,
    };
    if (!identical(messages, _scanned)) {
      _scanned = messages;
      _replies = _repliesAfter(messages);
      _question = _liveQuestion(messages);
    }
    final live = c.busy || c.pendingQuiz != null || c.pendingVoice != null ? -1 : _question;
    final out = <Widget>[];
    var sawArchived = false;
    var markedBoundary = false;
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m.archived) {
        sawArchived = true;
      } else if (sawArchived && !markedBoundary) {
        out.add(const _Caption('Kuma-sensei now works from a summary of the messages above'));
        markedBoundary = true;
      }
      switch (m.role) {
        case MessageRole.user:
          out.add(_Bubble(text: m.content, fromLearner: true, photos: m.photos));
        case MessageRole.note:
          final caption = widget.noteCaptions[m.kind];
          if (caption != null) out.add(_Caption(caption));
        case MessageRole.tool:
          break;
        case MessageRole.assistant:
          if (m.content.trim().isNotEmpty) {
            out.add(_Bubble(
              text: m.content,
              fromLearner: false,
              reply: _replies[i],
              onChoose: i == live ? c.send : null,
            ));
          }
          for (final call in m.toolCalls) {
            final result = results[call.id];
            // Unanswered: either still running (the status line covers
            // it) or the live quiz card below.
            final tool = c.toolNamed(call.name);
            if (result == null || tool == null) continue;
            final cached = _toolEntries[call.id];
            final Widget? entry;
            if (cached != null && identical(cached.$1, result)) {
              entry = cached.$2;
            } else {
              final args = call.args ?? const {};
              entry = tool.historyEntry(args, result.content) ??
                  _toolChip(tool, args, result.content);
              _toolEntries[call.id] = (result, entry);
            }
            if (entry != null) out.add(entry);
          }
      }
    }
    final voice = c.pendingVoice;
    if (voice != null) {
      out.add(_VoiceBubble(
        key: ObjectKey(voice.clip),
        voice: voice,
        onRetry: c.retryVoice,
        onDiscard: c.discardVoice,
      ));
    }
    if (c.streaming.value.isNotEmpty) {
      out.add(ValueListenableBuilder(
        valueListenable: c.streaming,
        builder: (_, text, _) => _Bubble(text: text, fromLearner: false, streaming: true),
      ));
    }
    final quiz = c.pendingQuiz;
    if (quiz != null) {
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: QuizCard(key: ObjectKey(quiz), spec: quiz.spec, onSubmit: c.answerQuiz),
      ));
    } else if (c.busy && (c.streaming.value.isEmpty || c.status != null)) {
      out.add(_Typing(label: c.status ?? 'Kuma-sensei is thinking…'));
    }
    final error = c.error;
    if (error != null) out.add(_ErrorNote(text: error, onRetry: c.retry));
    return out;
  }

  Widget? _toolChip(ChatTool tool, Map<String, dynamic> args, String result) {
    final activity = tool.activity(args, result);
    if (activity == null) return null;
    final failed = isToolError(result);
    return _ToolChip(
      icon: failed ? Icons.block_rounded : activity.icon,
      label: failed ? '${activity.label} — refused' : activity.label,
      failed: failed,
      onTap: !failed && activity.tappable && widget.onActivityTap != null
          ? () => widget.onActivityTap?.call(tool)
          : null,
    );
  }
}

/// For each message, the learner's next message after it: their answer,
/// when it was a question. An app note first means it went unanswered.
List<String?> _repliesAfter(List<ChatMessage> messages) {
  final out = List<String?>.filled(messages.length, null);
  String? next;
  for (var i = messages.length - 1; i >= 0; i--) {
    out[i] = next;
    final role = messages[i].role;
    if (role == MessageRole.user) {
      next = messages[i].content;
    } else if (role == MessageRole.note) {
      next = null;
    }
  }
  return out;
}

/// The one question a tap can still answer: the latest with options,
/// with nothing from the learner or the app after it. -1 when none.
int _liveQuestion(List<ChatMessage> messages) {
  for (var i = messages.length - 1; i >= 0; i--) {
    final m = messages[i];
    if (m.role == MessageRole.user || m.role == MessageRole.note) return -1;
    if (m.role == MessageRole.assistant &&
        (ChatChoices.parse(m.content)?.options.isNotEmpty ?? false)) {
      return i;
    }
  }
  return -1;
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.fromLearner,
    this.streaming = false,
    this.reply,
    this.onChoose,
    this.photos = const [],
  });

  final String text;
  final bool fromLearner;
  final bool streaming;

  /// Photos the learner attached to this message.
  final List<Photo> photos;

  /// On a multiple-choice question: the learner's reply, once given.
  final String? reply;

  /// Set on the question a tap can still answer.
  final ValueChanged<String>? onChoose;

  @override
  Widget build(BuildContext context) {
    return _BubbleFrame(
      fromLearner: fromLearner,
      child: fromLearner ? _learnerBody() : _tutorBody(),
    );
  }

  Widget _learnerBody() {
    if (photos.isEmpty) return SelectableText(text, style: _learnerText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in photos) PhotoBubbleImage(photo: p),
        if (text.isNotEmpty) SelectableText(text, style: _learnerText),
      ],
    );
  }

  Widget _tutorBody() {
    final choices = ChatChoices.parse(text);
    if (choices == null) return TutorMarkdown(text, selectable: !streaming);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (choices.text.isNotEmpty) TutorMarkdown(choices.text, selectable: !streaming),
        if (choices.options.isNotEmpty)
          ChoiceButtons(options: choices.options, reply: reply, onChoose: onChoose),
      ],
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.icon, required this.label, required this.failed, this.onTap});

  final IconData icon;
  final String label;
  final bool failed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = failed ? IunaPalette.raritySsrInk : IunaPalette.ink2;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: failed ? const Color(0x1FF3A7B5) : const Color.fromRGBO(74, 53, 32, 0.05),
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                  if (onTap != null) ...[
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 14, color: color),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    const line = Expanded(child: Divider(color: Color.fromRGBO(74, 53, 32, 0.12)));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(text, style: const TextStyle(fontSize: 11, color: IunaPalette.ink3)),
          ),
          line,
        ],
      ),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing({required this.label});
  final String label;

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: IunaPalette.ink3.withValues(
                        alpha: 0.3 + 0.7 * (((_anim.value * 3 - i) % 3) < 1 ? 1 : 0),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(widget.label, style: const TextStyle(fontSize: 12, color: IunaPalette.ink3)),
          ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.text, required this.onRetry});
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0x26F3A7B5),
        borderRadius: BorderRadius.circular(IunaRadii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: IunaPalette.raritySsrInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: IunaPalette.ink, height: 1.35)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

const _learnerText = TextStyle(fontSize: 14, height: 1.45, color: IunaPalette.ink);

class _BubbleFrame extends StatelessWidget {
  const _BubbleFrame({required this.fromLearner, required this.child});

  final bool fromLearner;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    const round = Radius.circular(18);
    const tight = Radius.circular(6);
    return Align(
      alignment: fromLearner ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width * (fromLearner ? 0.8 : 0.92)),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: paperPanelDecoration(
            gradient: fromLearner
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFF8E5), Color(0xFFFDE9C9)],
                  )
                : null,
            borderRadius: BorderRadius.only(
              topLeft: round,
              topRight: round,
              bottomLeft: fromLearner ? round : tight,
              bottomRight: fromLearner ? tight : round,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A held-to-speak clip on its way to becoming a message: its waveform
/// while it is transcribed, then the text it turned into.
class _VoiceBubble extends StatefulWidget {
  const _VoiceBubble({
    super.key,
    required this.voice,
    required this.onRetry,
    required this.onDiscard,
  });

  final PendingVoice voice;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    _syncSweep();
  }

  @override
  void didUpdateWidget(_VoiceBubble old) {
    super.didUpdateWidget(old);
    _syncSweep();
  }

  void _syncSweep() {
    if (!widget.voice.transcribing) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.voice.text;
    return _BubbleFrame(
      fromLearner: true,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topRight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: text != null
              ? SelectableText(text, key: const ValueKey('text'), style: _learnerText)
              : _clip(),
        ),
      ),
    );
  }

  Widget _clip() {
    final voice = widget.voice;
    final error = voice.error;
    return Column(
      key: const ValueKey('clip'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_rounded, size: 16, color: IunaPalette.ink3),
            const SizedBox(width: 6),
            SizedBox(
              width: 132,
              child: Waveform(
                levels: voice.clip.levels,
                fit: true,
                color: IunaPalette.ink2.withValues(alpha: error == null ? 0.55 : 0.3),
                sweep: voice.transcribing ? _sweep : null,
                sweepColor: IunaPalette.ctaBottom,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              clockLabel(voice.clip.length),
              style: const TextStyle(
                fontSize: 12,
                color: IunaPalette.ink3,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (error == null)
          const Text('Transcribing…', style: TextStyle(fontSize: 11, color: IunaPalette.ink3))
        else ...[
          Text(
            error,
            style: const TextStyle(fontSize: 12.5, height: 1.35, color: IunaPalette.raritySsrInk),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (voice.canRetry) TextButton(onPressed: widget.onRetry, child: const Text('Retry')),
              TextButton(onPressed: widget.onDiscard, child: const Text('Discard')),
            ],
          ),
        ],
      ],
    );
  }
}
