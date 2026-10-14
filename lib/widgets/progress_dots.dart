import 'package:flutter/material.dart';

/// One dot per card, the active one stretched into a honey pill. Falls
/// back to a continuous bar once the row would overflow.
class ProgressDots extends StatelessWidget {
  const ProgressDots({
    super.key,
    required this.count,
    required this.index,
    this.revealed = const {},
  });

  final int count;
  final int index;

  /// Cards already seen ahead of [index] (the booster can step back
  /// over them); they read as done.
  final Set<int> revealed;

  static const _gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE8B96B), Color(0xFFD99550)],
  );
  static const _doneColor = Color(0xE6B8D8C9);
  static const _trackColor = Color.fromRGBO(74, 53, 32, 0.18);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: LayoutBuilder(
        builder: (context, c) {
          // 6 wide + 6 gap per dot, plus 12 for the active pill.
          final dotsWidth = count * 12.0 + 12;
          if (count > 1 && dotsWidth > c.maxWidth) {
            return _ScaledProgressBar(
              count: count,
              index: index,
              width: c.maxWidth,
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: i == index ? _gradient : null,
                    color: i == index
                        ? null
                        : i < index || revealed.contains(i)
                        ? _doneColor
                        : _trackColor,
                    borderRadius: BorderRadius.circular(i == index ? 6 : 3),
                  ),
                ),
                if (i != count - 1) const SizedBox(width: 6),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ScaledProgressBar extends StatelessWidget {
  const _ScaledProgressBar({
    required this.count,
    required this.index,
    required this.width,
  });

  final int count;
  final int index;
  final double width;

  @override
  Widget build(BuildContext context) {
    final progress = ((index + 1) / count).clamp(0.0, 1.0);
    return Center(
      child: SizedBox(
        width: width,
        height: 6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: ProgressDots._trackColor),
              ),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: ProgressDots._gradient),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
