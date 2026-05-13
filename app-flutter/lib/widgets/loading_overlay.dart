import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LoadingOverlay extends StatefulWidget {
  const LoadingOverlay({
    required this.text,
    this.tintColor = AppColors.primary,
    super.key,
  });

  final String text;
  final Color tintColor;

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withAlpha(140)),
              ),
            ),
            Center(
              child: Container(
                width: 260,
                constraints: const BoxConstraints(minHeight: 180),
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.overlay.withAlpha(184),
                  borderRadius: BorderRadius.circular(AppRadii.overlay),
                  border: Border.all(
                    color: Colors.white.withAlpha(20),
                    width: 1.5,
                  ),
                  boxShadow: AppShadows.overlay,
                ),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final progress = _controller.value;
                    final pulse = (math.sin(progress * 2 * math.pi) + 1) / 2; // 0 to 1

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer rotating ring
                            Transform.rotate(
                              angle: progress * 2 * math.pi,
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: CustomPaint(
                                  painter: _CometRingPainter(
                                    color: widget.tintColor,
                                    strokeWidth: 4.5,
                                    tailLength: 1.6 * math.pi,
                                  ),
                                ),
                              ),
                            ),
                            // Inner rotating ring (spins backwards, faster)
                            Transform.rotate(
                              angle: -progress * 2 * math.pi * 1.5,
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.rotationY(math.pi),
                                child: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: CustomPaint(
                                    painter: _CometRingPainter(
                                      color: widget.tintColor.withAlpha(153), // ~0.6 opacity
                                      strokeWidth: 3.5,
                                      tailLength: 1.4 * math.pi,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Center pulsing dot
                            Container(
                              width: 12 + 6 * pulse,
                              height: 12 + 6 * pulse,
                              decoration: BoxDecoration(
                                color: widget.tintColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.tintColor.withAlpha(((0.4 + 0.4 * pulse) * 255).toInt()),
                                    blurRadius: 8 + 8 * pulse,
                                    spreadRadius: 2 + 2 * pulse,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        // Loading text
                        Opacity(
                          opacity: 0.6 + 0.4 * pulse,
                          child: Text(
                            widget.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.overlayText,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CometRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double tailLength;

  _CometRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.tailLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    paint.shader = SweepGradient(
      colors: [
        color.withAlpha(0),
        color,
      ],
      stops: [0.0, tailLength / (2 * math.pi)],
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      tailLength,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CometRingPainter oldDelegate) {
    return oldDelegate.color != color ||
           oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.tailLength != tailLength;
  }
}
