import 'package:flutter/material.dart';

/// 匹配成功庆祝动画
class ConfettiOverlay extends StatefulWidget {
  final bool show;
  final Widget child;

  const ConfettiOverlay({super.key, required this.show, required this.child});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void didUpdateWidget(ConfettiOverlay old) {
    super.didUpdateWidget(old);
    if (widget.show && !old.show) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.show)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.isCompleted) return const SizedBox.shrink();
              return CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(_controller.value),
              );
            },
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  static final _colors = [
    Colors.red, Colors.orange, Colors.yellow, Colors.green,
    Colors.blue, Colors.purple, Colors.pink, Color(0xFFE8A87C),
  ];

  _ConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < 40; i++) {
      final color = _colors[i % _colors.length];
      paint.color = color.withAlpha((255 * (1 - progress)).round());
      final x = (i * 37.0 + progress * size.width * 0.5) % size.width;
      final y = progress * size.height * (0.5 + (i % 5) * 0.1);
      final rect = Rect.fromCenter(
        center: Offset(x, y),
        width: 8,
        height: 8,
      );
      canvas.rotate(0.1 * i);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
