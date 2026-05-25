import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:listapay/core/theme/app_theme.dart';

const _listaPayLogoAsset = 'assets/images/loader_logo.png';

/// Animated ListaPay logo used as the app's primary loading indicator.
class BrandedLoadingIndicator extends StatefulWidget {
  const BrandedLoadingIndicator({
    super.key,
    this.size = 72,
    this.strokeWidth,
    this.showHalo = true,
  });

  final double size;
  final double? strokeWidth;
  final bool showHalo;

  @override
  State<BrandedLoadingIndicator> createState() =>
      _BrandedLoadingIndicatorState();
}

class _BrandedLoadingIndicatorState extends State<BrandedLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strokeWidth = widget.strokeWidth ?? math.max(2, widget.size * 0.08);
    final logoSize = widget.size * 0.82;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final wave = 0.5 + (math.sin(_controller.value * math.pi * 2) * 0.5);
        final haloScale = 0.9 + (wave * 0.16);
        final logoScale = 0.94 + (wave * 0.08);
        final glowAlpha = 0.08 + (wave * 0.08);
        final logoOffset = (0.5 - wave) * widget.size * 0.04;

        return SizedBox.square(
          dimension: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.showHalo)
                Transform.scale(
                  scale: haloScale,
                  child: Container(
                    width: widget.size * 0.9,
                    height: widget.size * 0.9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: glowAlpha),
                    ),
                  ),
                ),
              SizedBox.square(
                dimension: widget.size,
                child: CustomPaint(
                  painter: _LoadingSweepPainter(
                    progress: _controller.value,
                    color: AppColors.primary,
                    accentColor: AppColors.accent,
                    strokeWidth: strokeWidth,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, logoOffset),
                child: Transform.scale(
                  scale: logoScale,
                  child: Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(
                            alpha: 0.12 + (wave * 0.1),
                          ),
                          blurRadius: widget.size * 0.14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      _listaPayLogoAsset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.store_rounded,
                        size: logoSize * 0.52,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingSweepPainter extends CustomPainter {
  const _LoadingSweepPainter({
    required this.progress,
    required this.color,
    required this.accentColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color accentColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ringRect = Rect.fromCircle(
      center: rect.center,
      radius: (size.shortestSide / 2) - (strokeWidth / 2),
    );

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.12);

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          accentColor.withValues(alpha: 0),
          accentColor.withValues(alpha: 0.9),
          color.withValues(alpha: 0.95),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.38, 0.72, 1.0],
        transform: GradientRotation((progress * math.pi * 2) - (math.pi / 2)),
      ).createShader(ringRect);

    canvas.drawArc(ringRect, 0, math.pi * 2, false, basePaint);

    canvas.drawArc(ringRect, -math.pi / 2, math.pi * 1.65, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _LoadingSweepPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Centered loading indicator with optional message.
class SimpleLoading extends StatelessWidget {
  const SimpleLoading({super.key, this.message, this.size = 72});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandedLoadingIndicator(size: size),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-screen loading overlay.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface.withValues(alpha: 0.9),
      child: SimpleLoading(message: message),
    );
  }
}
