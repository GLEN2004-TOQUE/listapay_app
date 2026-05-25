import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:listapay/core/theme/app_theme.dart';

const _listaPayLogoAsset = 'assets/images/new-listapay-logo.png';

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
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strokeWidth = widget.strokeWidth ?? math.max(2, widget.size * 0.08);
    final logoSize = widget.size * 0.62;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final wave = 0.5 + (math.sin(_controller.value * math.pi * 2) * 0.5);
        final haloScale = 0.88 + (wave * 0.2);
        final logoScale = 0.96 + (wave * 0.08);

        return SizedBox.square(
          dimension: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.showHalo)
                Transform.scale(
                  scale: haloScale,
                  child: Container(
                    width: widget.size * 0.84,
                    height: widget.size * 0.84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(
                        alpha: 0.08 + (wave * 0.08),
                      ),
                    ),
                  ),
                ),
              SizedBox.square(
                dimension: widget.size,
                child: CircularProgressIndicator(
                  strokeWidth: strokeWidth,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              Transform.scale(
                scale: logoScale,
                child: Container(
                  width: logoSize,
                  height: logoSize,
                  padding: EdgeInsets.all(widget.size * 0.08),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(widget.size * 0.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(
                          alpha: 0.12 + (wave * 0.08),
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    _listaPayLogoAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.store_rounded,
                      size: logoSize * 0.52,
                      color: AppColors.primary,
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
      color: Colors.white.withValues(alpha: 0.85),
      child: SimpleLoading(message: message),
    );
  }
}
