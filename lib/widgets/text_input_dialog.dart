import 'package:flutter/material.dart';

/// What the learner chose in [showTextInputDialog]. [remove] is the
/// optional destructive action (e.g. "Remove key").
typedef TextInputResult = ({String text, bool remove});

/// A one-field dialog that owns its controller, so the field survives
/// the closing animation.
Future<TextInputResult?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String? message,
  String initial = '',
  String? hint,
  bool obscure = false,
  String confirmLabel = 'Save',
  String? removeLabel,
}) {
  return showDialog<TextInputResult>(
    context: context,
    builder: (_) => _TextInputDialog(
      title: title,
      message: message,
      initial: initial,
      hint: hint,
      obscure: obscure,
      confirmLabel: confirmLabel,
      removeLabel: removeLabel,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.message,
    required this.initial,
    required this.hint,
    required this.obscure,
    required this.confirmLabel,
    required this.removeLabel,
  });

  final String title;
  final String? message;
  final String initial;
  final String? hint;
  final bool obscure;
  final String confirmLabel;
  final String? removeLabel;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  late bool _hidden = widget.obscure;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _hidden,
            autocorrect: !widget.obscure,
            enableSuggestions: !widget.obscure,
            decoration: InputDecoration(
              hintText: widget.hint,
              suffixIcon: widget.obscure
                  ? IconButton(
                      icon: Icon(_hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    )
                  : null,
            ),
            onSubmitted: (v) => Navigator.of(context).pop((text: v.trim(), remove: false)),
          ),
        ],
      ),
      actions: [
        if (widget.removeLabel != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop((text: '', remove: true)),
            child: Text(widget.removeLabel!),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((text: _controller.text.trim(), remove: false)),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
