import 'package:flutter/material.dart';

import '../theme.dart';

/// The circular checkbox from Microsoft To Do: an empty circle that fills
/// with Microsoft blue and a white check when the task is completed.
/// Hovering (desktop) shows a faint check inside the empty circle, and
/// tapping plays a short scale animation.
class CircleCheckbox extends StatefulWidget {
  final bool checked;
  final ValueChanged<bool> onChanged;
  final double size;

  const CircleCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    this.size = 22,
  });

  @override
  State<CircleCheckbox> createState() => _CircleCheckboxState();
}

class _CircleCheckboxState extends State<CircleCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF4CC2FF) : AppTheme.msBlue;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () {
          _controller.forward().then((_) => _controller.reverse());
          widget.onChanged(!widget.checked);
        },
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.checked ? accent : Colors.transparent,
              border: Border.all(
                color: widget.checked ? accent : const Color(0xFF8A8886),
                width: 1.5,
              ),
            ),
            child: widget.checked
                ? Icon(Icons.check,
                    size: widget.size * 0.7, color: Colors.white)
                : _hovering
                    ? Icon(Icons.check,
                        size: widget.size * 0.7,
                        color: accent.withOpacity(0.55))
                    : null,
          ),
        ),
      ),
    );
  }
}
