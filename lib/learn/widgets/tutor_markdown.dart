import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../theme/iuna_theme.dart';
import '../../core/japanese_text.dart';
import '../words/segmenter.dart';
import '../words/tutor_words.dart';
import 'word_sheet.dart';

/// The tutor's markdown in the app's ink and paper. Links render as
/// text: nothing in a lesson should send the learner out of the app.
///
/// With [lookUp], each Japanese word is tappable for its reading and
/// meanings, so the tutor needn't write readings into its prose.
class TutorMarkdown extends StatefulWidget {
  const TutorMarkdown(
    this.data, {
    super.key,
    this.fontSize = 14,
    this.selectable = true,
    this.lookUp = true,
  });

  final String data;
  final double fontSize;
  final bool selectable;

  /// Off while a reply streams in, and where a tap would give an
  /// answer away.
  final bool lookUp;

  @override
  State<TutorMarkdown> createState() => _TutorMarkdownState();
}

const _wordScheme = 'iuna-word:';

class _TutorMarkdownState extends State<TutorMarkdown> {
  Map<String, List<TextWord>>? _words;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(TutorMarkdown old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data || old.lookUp != widget.lookUp) _read();
  }

  void _read() {
    _words = null;
    if (!widget.lookUp) return;
    final words = TutorWords.instance;
    _words = words.cached(widget.data);
    if (_words != null) return;
    final text = widget.data;
    words.read(text).then((found) {
      if (!mounted || found == null || found.isEmpty || widget.data != text || !widget.lookUp) {
        return;
      }
      setState(() => _words = found);
    });
  }

  void _onTapLink(String text, String? href, String title) {
    final words = _words;
    if (words == null || href == null || !href.startsWith(_wordScheme)) return;
    // A run is kana and kanji only: it never holds the slash.
    final [run, at] = href.substring(_wordScheme.length).split('/');
    showWordSheet(context, text, words[run]![int.parse(at)]);
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    return MarkdownBody(
      // The body parses only when its data or style changes; words
      // arriving for the same text need a fresh parse.
      key: ValueKey(words),
      data: widget.data,
      selectable: widget.selectable,
      styleSheet: tutorMarkdownStyle(context, widget.fontSize),
      inlineSyntaxes: words == null ? null : [_WordSyntax(words)],
      onTapLink: _onTapLink,
    );
  }
}

/// Turns each word of a Japanese run into a link whose target names it.
/// Links are already tappable inside selectable text, and the tutor's
/// own links lead nowhere.
class _WordSyntax extends md.InlineSyntax {
  _WordSyntax(this.words) : super(japaneseRun.pattern);

  final Map<String, List<TextWord>> words;

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final run = match[0]!;
    final list = words[run] ?? const <TextWord>[];
    var at = 0;
    for (var i = 0; i < list.length; i++) {
      final w = list[i];
      if (w.start > at) parser.addNode(md.Text(run.substring(at, w.start)));
      parser.addNode(
        md.Element('a', [md.Text(run.substring(w.start, w.end))])
          ..attributes['href'] = '$_wordScheme$run/$i',
      );
      at = w.end;
    }
    if (at < run.length) parser.addNode(md.Text(run.substring(at)));
    return true;
  }
}

/// Built once per theme and size: every bubble asks for it on every
/// rebuild, and `MarkdownBody` compares the sheet field by field.
final _styles = Expando<Map<double, MarkdownStyleSheet>>();

MarkdownStyleSheet tutorMarkdownStyle(BuildContext context, double size) {
  final theme = Theme.of(context);
  return (_styles[theme] ??= {}).putIfAbsent(size, () => _buildStyle(theme, size));
}

MarkdownStyleSheet _buildStyle(ThemeData theme, double size) {
  final base = TextStyle(fontSize: size, height: 1.5, color: IunaPalette.ink);
  const rule = Color.fromRGBO(74, 53, 32, 0.12);
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: base,
    // Every Japanese word is a link (see [_WordSyntax]); underlining
    // them all would bury the text.
    a: base,
    strong: base.copyWith(fontWeight: FontWeight.w700),
    em: base.copyWith(fontStyle: FontStyle.italic),
    del: base.copyWith(decoration: TextDecoration.lineThrough),
    h1: base.copyWith(fontSize: size + 5, fontWeight: FontWeight.w800, height: 1.3),
    h2: base.copyWith(fontSize: size + 3, fontWeight: FontWeight.w800, height: 1.3),
    h3: base.copyWith(fontSize: size + 1, fontWeight: FontWeight.w700, height: 1.3),
    h4: base.copyWith(fontWeight: FontWeight.w700),
    listBullet: base,
    blockSpacing: 8,
    code: base.copyWith(
      fontSize: size - 0.5,
      backgroundColor: const Color.fromRGBO(74, 53, 32, 0.07),
    ),
    codeblockPadding: const EdgeInsets.all(10),
    codeblockDecoration: BoxDecoration(
      color: IunaPalette.bg2,
      borderRadius: BorderRadius.circular(IunaRadii.sm),
    ),
    blockquote: base.copyWith(color: IunaPalette.ink2),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
    blockquoteDecoration: const BoxDecoration(
      color: IunaPalette.paper2,
      border: Border(left: BorderSide(color: IunaPalette.bellGold, width: 3)),
    ),
    tableHead: base.copyWith(fontWeight: FontWeight.w700),
    tableBody: base,
    tableBorder: TableBorder.all(color: rule, width: 0.5),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    tableColumnWidth: const FlexColumnWidth(),
    horizontalRuleDecoration: const BoxDecoration(
      border: Border(top: BorderSide(color: rule, width: 1)),
    ),
  );
}
