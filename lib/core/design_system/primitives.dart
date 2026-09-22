import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/draconic_theme.dart';
import 'tr_case.dart';

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

// 4. C-1: Buton Hiyerarşisi — vurgu dolgudan gelir, renkten değil.
// Birincil: dolu amber + glow (enableHeavyGlow kapalıyken veya aydınlık
// temada glow yerine gölge+çerçeve, C-4 gereği). İkincil: surfaceLight
// dolgu + borderSubtle çerçeve. Üçüncül: sadece metin/ikon, dolgusuz.
// Yıkıcı: kırmızı, yalnızca onay adımlarında kullanılmalı.
// NOT: NeonButton (yukarıda) hiçbir yerde kullanılmıyordu (grep ile
// doğrulandı) — AppButton onun yerini alıyor, NeonButton dokunulmadan
// referans/geriye uyumluluk için duruyor.
enum ButtonLevel { primary, secondary, tertiary, destructive }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final ButtonLevel level;
  final bool expand;
  final EdgeInsetsGeometry padding;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.level = ButtonLevel.secondary,
    this.expand = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  /// Yalnızca ikon gösteren kompakt varyant (liste satırlarındaki aksiyon
  /// butonları için) — varsayılan seviye üçüncül, gerekirse override edilir.
  const AppButton.icon({
    super.key,
    required this.icon,
    required this.onPressed,
    this.level = ButtonLevel.tertiary,
  })  : text = '',
        trailingIcon = null,
        expand = false,
        padding = const EdgeInsets.all(8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    final disabled = onPressed == null;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16),
          if (text.isNotEmpty) const SizedBox(width: 8),
        ],
        if (text.isNotEmpty)
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.2)),
        if (trailingIcon != null) ...[
          const SizedBox(width: 4),
          Icon(trailingIcon, size: 16),
        ],
      ],
    );

    switch (level) {
      case ButtonLevel.primary:
        final glow = theme.enableHeavyGlow && theme.isDark;
        final lightFallback = !theme.isDark;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: glow
                ? [BoxShadow(color: theme.primaryAmber.withValues(alpha: 0.3), blurRadius: 16, spreadRadius: 2, offset: const Offset(0, 4))]
                : lightFallback
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3))]
                    : null,
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.primaryAmber,
              foregroundColor: theme.background,
              disabledBackgroundColor: theme.primaryAmber.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: lightFallback ? BorderSide(color: theme.borderSubtle) : BorderSide.none,
              ),
              padding: padding,
            ),
            onPressed: onPressed,
            child: content,
          ),
        );
      case ButtonLevel.secondary:
        return OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: theme.surfaceLight,
            foregroundColor: theme.textPrimary,
            disabledForegroundColor: theme.textMuted,
            side: BorderSide(color: theme.borderSubtle),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: padding,
          ),
          onPressed: onPressed,
          child: content,
        );
      case ButtonLevel.tertiary:
        return TextButton(
          style: TextButton.styleFrom(
            foregroundColor: disabled ? theme.textMuted : theme.textSecondary,
            padding: padding,
          ),
          onPressed: onPressed,
          child: content,
        );
      case ButtonLevel.destructive:
        return FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.dangerRed,
            foregroundColor: Colors.white,
            disabledBackgroundColor: theme.dangerRed.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: padding,
          ),
          onPressed: onPressed,
          child: content,
        );
    }
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
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    // P0-D: bu rozet ekranın en üstünde, kendi temalı arkaplan .webp
    // görselinin üzerinde duruyor. Eski kod sadece %16 alfa'lı bir renk
    // katmanı çiziyordu — arkasındaki görsel o noktada koyu olduğunda
    // (çoğu ekranda öyle), rozet temadan bağımsız olarak siyaha yakın bir
    // daire gibi görünüyordu ("her sekmede üstte beyaz temada siyah kalan
    // kutucuklar" şikayeti). Önce opak bir tema-zemini (header stat pill'lerle
    // aynı `surfaceDark` katmanı) çizilip üstüne aksan rengi bindirilerek
    // arkadaki görselden bağımsız, temayla tutarlı bir rozet elde edildi.
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.surfaceDark.withValues(alpha: 0.88),
        border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFDE68A).withValues(alpha: 0.18), blurRadius: 10, spreadRadius: 0.5),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Opak zeminin üstünde aksan rengi tonu — artık arkadaki görselden
          // değil, sadece opak `surfaceDark` zemininden besleniyor.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.22)),
            ),
          ),
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
    // Gerçek cihaz geri bildirimi: parşömen (aydınlık) temaya geçince bu
    // başlık — TÜM ekranların en üstündeki "PROFİL"/"ARENA"/"SIRALAMA" gibi
    // metin — sabit Colors.white/gri kullandığı için açık krem zemin
    // üzerinde neredeyse okunaksız kalıyordu. Artık DraconicTheme'den okuyor
    // (Zindan'da hâlâ beyaza, Parşömen'de koyu kahveye düşer), tıpkı
    // ekranların artık tamamının kullandığı diğer token'lar gibi.
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // UI/UX Düzeltme Listesi — P0-3: Dart'ın toUpperCase()'i yerine
          // Türkçe kurallarına göre büyüten toUpperCaseTr() (i → İ).
          title.toUpperCaseTr(),
          style: GoogleFonts.lora(color: theme.textPrimary, fontSize: fontSize, fontWeight: FontWeight.w700, letterSpacing: 1.6),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [theme.primaryAmber, theme.primaryAmber.withValues(alpha: 0.0)]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
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
        // P0-D: kaynak 1.1MB'lık yüksek çözünürlüklü PNG — gösterilen
        // boyuta (size) göre cache verilerek gereksiz tam-çözünürlük
        // decode'u önlendi.
        cacheWidth: (size * MediaQuery.of(context).devicePixelRatio).round(),
        cacheHeight: (size * MediaQuery.of(context).devicePixelRatio).round(),
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

// 5. Boş Kelime Havuzu Durumu — egzersiz ekranları (Hızlı Test, Eşleştirme,
// Dinle & Yaz, Hafıza Zindanı Karma Mod) kullanıcının pratik yapacak yeterli
// kelimesi olmadığında bunu gösterir. Düz bir metin yerine, kullanıcıyı
// doğrudan Kitaplık'a yönlendiren tek bir eylem sunar — [onGoToLibrary]
// verilmezse (ekran bir callback almadan bağımsız açıldıysa) yalnızca geri
// döner, hiçbir zaman kırık bir buton göstermez.
class EmptyWordPoolState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onGoToLibrary;

  const EmptyWordPoolState({
    super.key,
    this.title = 'Havuz Şu An Boş',
    required this.message,
    this.onGoToLibrary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_stories_rounded, size: 44, color: Color(0xFFF59E0B)),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.05, 1.05),
                  duration: 1200.ms,
                ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: theme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12.5, color: theme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF070B14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: () {
                  final nav = Navigator.of(context);
                  if (nav.canPop()) nav.pop();
                  onGoToLibrary?.call();
                },
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: Text('Kitaplığa Git', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 5. P1-3: Paylaşılan kitap kimliği — harf monogramı + kitaba deterministik
// atanan palet rengi. Önceden Lobi (main.dart) harf monogramı, Kitaplık
// (library_screen.dart) emoji kullanıyordu; aynı kitap iki ekranda farklı
// görünüyordu. Renk paleti, main.dart'taki eski `_getBookBadgeColor`'dan
// birebir taşındı (davranış aynı) — C-2/P1-4 (tema token'larına taşınma)
// henüz yapılmadı, bu yüzden hâlâ ham hex; ayrı, planlı bir iş.
class BookCover extends StatelessWidget {
  final String title;
  final double size;

  const BookCover({super.key, required this.title, this.size = 28});

  static const List<Color> _palette = [
    Color(0xFF38BDF8),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFFA855F7),
  ];

  static Color colorFor(String title) => _palette[title.length % _palette.length];

  @override
  Widget build(BuildContext context) {
    final color = colorFor(title);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.21),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : 'B',
          style: GoogleFonts.lora(color: color, fontWeight: FontWeight.bold, fontSize: size * 0.5),
        ),
      ),
    );
  }
}

// 6. P0-D: Pratik ekranlarındaki (quiz/eşleştirme/SRS/imla/boşluk
// doldurma/dinleme/ters test/hız turu) "teşvik" (cheer) bildirim kapsülü —
// tek, paylaşılan tanım. Önceden her egzersiz dosyasında ayrı ayrı,
// birebir kopyalanmış, düz `successEmerald` dolgulu + ikonsuz + varsayılan
// (Outfit DEĞİL) fontlu bir kapsül olarak duruyordu; bu hem 8 yerde bakım
// yükü yaratıyordu hem de fontu uygulamanın geri kalanından (her yerde
// GoogleFonts.outfit) farklı olduğu için "yabancı" duruyordu.
//
// DÜZELTME NOTU: İLK sürüm bunu yarı saydam nötr (surfaceDark) bir zemine
// çevirmişti — ama karanlık temada surfaceDark, uygulamanın zaten neredeyse
// siyah background'una çok yakın bir ton olduğundan kapsül pratikte
// GÖRÜNMEZ hale geliyordu (kullanıcı bildirimi: "3 doğru bildim ama
// çıkmadı"). Bu yüzden canlı aksan rengi (successEmerald/dangerRed/
// primaryAmber) dolgu GERİ getirildi — görünürlük önceliklidir — sadece
// köşe/kenarlık/gölge/font uygulamanın diline (GlassPanel/IgnisAlert'teki
// gibi ince, yarı saydam bir üst kenarlık + daha yumuşak gölge) yaklaştırıldı.
class CheerToast extends StatelessWidget {
  final String? message;
  final Color? accentColor;

  const CheerToast({super.key, required this.message, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    final accent = accentColor ?? theme.successEmerald;
    final bool visible = message != null;

    return Positioned(
      top: 10,
      left: 20,
      right: 20,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        offset: visible ? Offset.zero : const Offset(0, -1.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            message ?? '',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
        ),
      ),
    );
  }
}