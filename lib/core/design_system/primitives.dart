import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/draconic_theme.dart';

// 1. Performans Duyarlı Cam Panel (GlassPanel)
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    final defaultRadius = borderRadius ?? BorderRadius.circular(22);

    if (theme.glassBlurSigma > 0) {
      return ClipRRect(
        borderRadius: defaultRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: theme.glassBlurSigma, sigmaY: theme.glassBlurSigma),
          child: _buildContent(theme, defaultRadius),
        ),
      );
    }
    
    return _buildContent(theme, defaultRadius);
  }

  Widget _buildContent(DraconicTheme theme, BorderRadius radius) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceDark.withValues(alpha: 0.65),
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: child,
    );
  }
}

// 2. Performans Duyarlı Zindan Kartı (DungeonCard)
class DungeonCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const DungeonCard({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.borderSubtle, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

// 3. Kalite Katmanına Bağlı Neon Buton (NeonButton)
class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;

  const NeonButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: theme.enableHeavyGlow
            ? [
                BoxShadow(
                  color: theme.primaryAmber.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: theme.primaryAmber,
          foregroundColor: theme.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. Ignis Statik Portre & Performans Dostu Nefes Alma Efekti (Rive Alternatifi)
class IgnisCharacterPortrait extends StatelessWidget {
  final double size;
  const IgnisCharacterPortrait({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/ignis_avatar.png',
        fit: BoxFit.contain,
      ),
    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
     .scale(
       begin: const Offset(1.0, 1.0),
       end: const Offset(1.03, 1.03),
       duration: 3000.ms,
       curve: Curves.easeInOut,
     );
  }
}