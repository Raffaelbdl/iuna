import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';

/// Frosted search box with a clear-X once something is typed.
class IunaSearchField extends StatelessWidget {
  const IunaSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hint,
    this.autofocus = false,
    this.height,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final bool autofocus;
  final double? height;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: height == null ? 10 : 0,
        ),
        decoration: BoxDecoration(
          color: const Color(0xB3FFFDF6),
          borderRadius: BorderRadius.circular(IunaRadii.md),
          border: Border.all(
            color: const Color.fromRGBO(74, 53, 32, 0.08),
            width: 0.5,
          ),
          boxShadow: panelShadow(),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 18, color: IunaPalette.ink3),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: autofocus,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: IunaPalette.inkMute),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: IunaPalette.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: IunaPalette.ink3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
