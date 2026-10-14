import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';

/// Honey pill for a screen's primary action: full width, or hugging its
/// label with [shrinkWrap].
class IunaCtaButton extends StatelessWidget {
  const IunaCtaButton({
    super.key,
    required this.label,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon,
    this.shrinkWrap = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        decoration: ctaDecoration(),
        child: Row(
          mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 16, color: kCtaInk),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: kCtaInk,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 10),
              Icon(trailingIcon, size: 18, color: kCtaInk),
            ],
          ],
        ),
      ),
    );
  }
}
