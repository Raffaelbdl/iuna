import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../theme/iuna_theme.dart';

/// The tutor's markdown in the app's ink and paper. Links render as
/// text: nothing in a lesson should send the learner out of the app.
class TutorMarkdown extends StatelessWidget {
  const TutorMarkdown(
    this.data, {
    super.key,
    this.fontSize = 14,
    this.selectable = true,
  });

  final String data;
  final double fontSize;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: selectable,
      styleSheet: tutorMarkdownStyle(context, fontSize),
      onTapLink: (text, href, title) {},
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
