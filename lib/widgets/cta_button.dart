import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';
import 'tappable.dart';

/// Honey pill for a screen's primary action: full width, or hugging its
/// label with [shrinkWrap]. A null [onTap] shows it disabled, to the eye
/// and to a screen reader.
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
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
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
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: IunaText.subtitle.copyWith(
                    color: kCtaInk,
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 10),
                Icon(trailingIcon, size: 18, color: kCtaInk),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Paper pill for a screen's secondary action: full width under an
/// [IunaCtaButton] ("Back home", "Done"), or hugging its label with
/// [shrinkWrap]. A null [onTap] shows it disabled.
class IunaGhostButton extends StatelessWidget {
  const IunaGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.leadingIcon,
    this.shrinkWrap = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final ink = onTap == null ? IunaPalette.inkMute : IunaPalette.ink2;
    return Tappable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        decoration: ghostPillDecoration(
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(74, 53, 32, 0.25),
              blurRadius: 14,
              offset: Offset(0, 6),
              spreadRadius: -10,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 18, color: ink),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: IunaText.label.copyWith(
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
