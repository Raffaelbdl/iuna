import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/japanese_text.dart';
import '../../theme/iuna_theme.dart';
import '../deck.dart';
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
    this.bookmarks,
  });

  final String data;
  final double fontSize;
  final bool selectable;

  /// Off while a reply streams in, and where a tap would give an
  /// answer away.
  final bool lookUp;

  /// Where a looked-up word not yet collected can be wishlisted.
  final WordBookmarks? bookmarks;

  @override
  State<TutorMarkdown> createState() => _TutorMarkdownState();
}

/// The markdown tag a word becomes; its `id` attribute is `run/index`.
const _wordTag = 'jw';

class _TutorMarkdownState extends State<TutorMarkdown> {
  Map<String, List<TextWord>>? _words;

  /// Where the pressed word, or the one whose sheet is open, is laid out.
  /// Painted over the text rather than styled into it: restyling a span
  /// re-parses the whole message, which costs a long chapter frames and
  /// would tear the text's selection gestures down mid-press.
  final _lit = ValueNotifier<List<Rect>>(const []);

  final _recognizers = <String, TapGestureRecognizer>{};

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

  @override
  void dispose() {
    _disposeRecognizers();
    _lit.dispose();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _read() {
    _disposeRecognizers();
    _lit.value = const [];
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

  TapGestureRecognizer _recognizer(String id) => _recognizers.putIfAbsent(id, () {
    final r = TapGestureRecognizer();
    return r
      ..onTapDown = ((d) => _lit.value = _boxesOf(r, d.globalPosition))
      ..onTapCancel = (() => _lit.value = const [])
      ..onTap = (() => _open(id));
  });

  /// The boxes of the span [recognizer] drives at [global], in this
  /// widget's coordinates: that occurrence only, however often the word
  /// repeats.
  List<Rect> _boxesOf(GestureRecognizer recognizer, Offset global) {
    final host = context.findRenderObject();
    if (host is! RenderBox) return const [];
    final hits = BoxHitTestResult();
    host.hitTest(hits, position: host.globalToLocal(global));
    for (final entry in hits.path) {
      final (box, text, at, boxes) = switch (entry.target) {
        final RenderParagraph p => (
          p,
          p.text,
          p.getPositionForOffset(p.globalToLocal(global)).offset,
          p.getBoxesForSelection,
        ),
        final RenderEditable e when e.text != null => (
          e,
          e.text!,
          e.getPositionForPoint(global).offset,
          e.getBoxesForSelection,
        ),
        _ => (null, null, null, null),
      };
      if (box == null) continue;
      final range = _spanAt(text!, recognizer, at!);
      if (range == null) return const [];
      final toHost = box.getTransformTo(host);
      return [for (final b in boxes!(range)) MatrixUtils.transformRect(toHost, b.toRect())];
    }
    return const [];
  }

  Future<void> _open(String id) async {
    // A run is kana and kanji only: it never holds the slash.
    final [run, at] = id.split('/');
    final word = _words![run]![int.parse(at)];
    await showWordSheet(
      context,
      run.substring(word.start, word.end),
      word,
      bookmarks: widget.bookmarks,
    );
    if (mounted) _lit.value = const [];
  }

  @override
  Widget build(BuildContext context) {
    final words = _words;
    final body = MarkdownBody(
      // The body parses only when its data or style changes; words
      // arriving for the same text need a fresh parse.
      key: ValueKey(words),
      data: widget.data,
      selectable: widget.selectable,
      styleSheet: tutorMarkdownStyle(context, widget.fontSize),
      inlineSyntaxes: words == null ? null : [_WordSyntax(words)],
      builders: words == null ? const {} : {_wordTag: _WordBuilder(this)},
      onTapLink: (text, href, title) {},
    );
    if (words == null) return body;
    // Over the text, not under it: a quote's or a table's own background
    // would hide anything painted beneath the body.
    return CustomPaint(foregroundPainter: WordHighlight(_lit), child: body);
  }
}

/// The text range of the span [recognizer] drives that covers offset [at].
TextSelection? _spanAt(InlineSpan root, GestureRecognizer recognizer, int at) {
  var offset = 0;
  TextSelection? found;
  root.visitChildren((span) {
    final length = span is TextSpan ? span.text?.length ?? 0 : 1;
    if (span is TextSpan &&
        span.recognizer == recognizer &&
        at >= offset &&
        at <= offset + length) {
      found = TextSelection(baseOffset: offset, extentOffset: offset + length);
      return false;
    }
    offset += length;
    return true;
  });
  return found;
}

/// Marks a pressed word like a link: a soft fill and a bar beneath.
@visibleForTesting
class WordHighlight extends CustomPainter {
  WordHighlight(this.lit) : super(repaint: lit);

  final ValueListenable<List<Rect>> lit;

  static final _fill = Paint()..color = IunaPalette.bellGold.withValues(alpha: 0.3);
  static final _bar = Paint()..color = IunaPalette.ctaBottom;

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in lit.value) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), _fill);
      canvas.drawRect(Rect.fromLTRB(r.left, r.bottom - 2, r.right, r.bottom), _bar);
    }
  }

  @override
  bool shouldRepaint(WordHighlight old) => old.lit != lit;
}

/// Wraps each word of a Japanese run in a [_wordTag] element naming it.
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
        md.Element(_wordTag, [md.Text(run.substring(w.start, w.end))])
          ..attributes['id'] = '$run/$i',
      );
      at = w.end;
    }
    if (at < run.length) parser.addNode(md.Text(run.substring(at)));
    return true;
  }
}

/// A word as a tappable span of the paragraph around it.
class _WordBuilder extends MarkdownElementBuilder {
  _WordBuilder(this.state);

  final _TutorMarkdownState state;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return Text.rich(
      TextSpan(
        text: element.textContent,
        // A faint dotted line says the word opens; it stays light so
        // the kanji still read cleanly.
        style: (parentStyle ?? const TextStyle()).copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationColor: IunaPalette.ink3.withValues(alpha: 0.5),
        ),
        mouseCursor: SystemMouseCursors.click,
        recognizer: state._recognizer(element.attributes['id']!),
      ),
    );
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
    a: base.copyWith(decoration: TextDecoration.underline),
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
