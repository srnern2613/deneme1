import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
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

// 4b. Ekran Başlığı Sol Rozeti — her sayfanın kendi kimlik rengini korur,
// ama ince altın halka + hafif parıltı ile hepsini "aynı aileden" gösterir.
// Dokunulabilir bir rozet ise (ör. Arena ayarları) sağ-altta küçük bir
// vurgu noktası, kullanıcıya orada bir aksiyon olduğunu sezdirir.
class ScreenHeaderBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  final bool showAffordanceDot;
  final Color affordanceDotColor;

  const ScreenHeaderBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
    this.onTap,
    this.showAffordanceDot = false,
    this.affordanceDotColor = const Color(0xFF38BDF8),
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFDE68A).withValues(alpha: 0.18), blurRadius: 10, spreadRadius: 0.5),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(icon, color: color, size: size * 0.43)),
          if (showAffordanceDot)
            Positioned(
              bottom: -1,
              right: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: affordanceDotColor,
                  border: Border.all(color: const Color(0xFF070B14), width: 2),
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return badge;
    return GestureDetector(onTap: onTap, child: badge);
  }
}

// 4c. Rün Kazınmış Ekran Başlığı — geniş harf aralıklı büyük harf metin +
// altında altından şeffafa geçen ince bir "rün çizgisi". Sadece görsel
// sunum; hiçbir ekranın state'i veya veri kaynağı bu widget'a bağlı değil.
class RuneTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double fontSize;

  const RuneTitle({super.key, required this.title, this.subtitle, this.fontSize = 20});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.lora(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w700, letterSpacing: 1.6),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Colors.transparent]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
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