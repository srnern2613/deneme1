import 'package:flutter/material.dart';

enum DevicePerformanceTier { high, low }

// UI/UX DÜZELTME LİSTESİ — T-1/T-2: DraconicTheme artık iki bağımsız eksen
// taşıyor: performanceTier (blur/glow — cihaz gücüne göre) ve isDark (renk
// şeması — kullanıcı tercihine göre, Karanlık/Zindan ↔ Aydınlık/Parşömen).
// Ekranlar artık DraconicTheme.primaryAmber gibi STATİK erişim yerine
// Theme.of(context).extension<DraconicTheme>()! ile context üzerinden
// okumalı — bu, tema değiştiğinde tüm ağacın otomatik yeniden çizilmesini
// sağlıyor. Mevcut ekranların ham hex'lerden buna taşınması ayrı, kademeli
// bir iş (bkz. docs/draconic_lingua_ui_iyilestirme_listesi_1.md, Sıra 1).
class DraconicTheme extends ThemeExtension<DraconicTheme> {
  final DevicePerformanceTier performanceTier;

  // Karanlık (Zindan) mı, Aydınlık (Parşömen) mı — T-6'daki tema anahtarının
  // hangi paleti aktif ettiğini burada taşıyoruz.
  final bool isDark;

  // Zemin ve Yüzeyler (T-2: zemin/yüzey/yükseltilmiş yüzey/çerçeve)
  final Color background;
  final Color surfaceDark;
  final Color surfaceLight;
  final Color borderSubtle;

  // Metin
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Vurgu Renkleri (C-2: her renk uygulamanın tamamında TEK iş yapar)
  final Color primaryAmber;
  final Color successEmerald;
  final Color infoTeal;
  final Color cognitiveIndigo;
  final Color dangerRed;

  // Sekme/filtre etiketi rengi (Dükkan üst kategori sekmeleri, Sözlük filtre
  // çipleri gibi seçili OLMAYAN yatay sekme yazıları için) — bilerek ayrı bir
  // token: textSecondary hem koyu hem parşömen temada teknik olarak yeterli
  // kontrasta sahip olsa da, gerçek cihazda bu özel bağlamda (küçük punto +
  // çip zemini) okunmadığı bildirildi. tabLabel, her iki temada da o
  // bağlam için özel olarak seçilmiş, en yüksek okunabilirliği hedefleyen
  // bağımsız bir renk taşır.
  final Color tabLabel;

  // Performansa Bağlı Değişkenler
  final double glassBlurSigma;
  final bool enableHeavyGlow;

  const DraconicTheme({
    required this.performanceTier,
    required this.isDark,
    required this.background,
    required this.surfaceDark,
    required this.surfaceLight,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primaryAmber,
    required this.successEmerald,
    required this.infoTeal,
    required this.cognitiveIndigo,
    required this.dangerRed,
    required this.tabLabel,
    required this.glassBlurSigma,
    required this.enableHeavyGlow,
  });

  factory DraconicTheme.highEnd() {
    return const DraconicTheme(
      performanceTier: DevicePerformanceTier.high,
      isDark: true,
      background: Color(0xFF070B14),
      surfaceDark: Color(0xFF0F172A),
      surfaceLight: Color(0xFF111827),
      borderSubtle: Color(0xFF1F2937),
      textPrimary: Colors.white,
      textSecondary: Color(0xFF94A3B8),
      textMuted: Color(0xFF64748B),
      primaryAmber: Color(0xFFF59E0B),
      successEmerald: Color(0xFF10B981),
      infoTeal: Color(0xFF38BDF8),
      cognitiveIndigo: Color(0xFF6366F1),
      dangerRed: Color(0xFFEF4444),
      // Açık lavanta-beyaz — mevcut indigo vurgu ailesiyle uyumlu, koyu
      // zeminde/çip yüzeyinde net okunuyor.
      tabLabel: Color(0xFFEDE9FE),
      glassBlurSigma: 18.0,
      enableHeavyGlow: true,
    );
  }

  factory DraconicTheme.lowEnd() {
    final DraconicTheme base = DraconicTheme.highEnd();
    final DraconicTheme result = base.copyWith(
      performanceTier: DevicePerformanceTier.low,
      glassBlurSigma: 0.0, // Düşük cihazlarda cam efekti kapatılır
      enableHeavyGlow: false,
    );
    return result;
  }

  // T-2: Parşömen (Aydınlık) paleti — taslak değerler, kontrast testiyle son
  // hali alınacak (gövde metni 4.5:1, büyük metin/ikon 3:1). T-3 gereği
  // glow ve blur aydınlık zeminde çalışmadığından burada da düşük-tier
  // davranışıyla (glassBlurSigma: 0, enableHeavyGlow: false) aynı opak
  // yüzey + borderSubtle çerçeve yolunu kullanır — A-7'de tarif edilen
  // "tek koddan beslenme" burada gerçekleşiyor.
  // UI/UX Düzeltme Listesi — Faz A1: parşömen paleti kullanıcı geri
  // bildirimine göre kalibre edildi. textPrimary artık saf siyaha yakın
  // (#1C1917) değil, sıcak koyu kahve (#2C221E) — "tema geçişinde siyah
  // kalan metin/ikon" şikayetinin köküydü.
  // P0-D — 2. tur kalibrasyon: kullanıcı "arka plan çok cırtlak, uygulamanın
  // geri kalanıyla uyumsuz" geri bildirimini verdi. İki değişiklik birlikte
  // uygulandı: (1) background/surfaceLight/borderSubtle'daki hardal/haki
  // tonu törpülenip daha nötr, soluk bir kağıt hissine çekildi; (2) soğuk ve
  // canlı duran infoTeal/cognitiveIndigo, sıcak kremle çatışmasın diye daha
  // sakin/sıcak tonlara kaydırıldı — primaryAmber (marka rengi) ve
  // successEmerald zaten yeterince sakin olduğu için dokunulmadı.
  factory DraconicTheme.parchment() {
    return const DraconicTheme(
      performanceTier: DevicePerformanceTier.low,
      isDark: false,
      background: Color(0xFFF7F3E8),
      surfaceDark: Color(0xFFFDFBF5),
      surfaceLight: Color(0xFFEDE6D3),
      borderSubtle: Color(0xFFDCD0B4),
      textPrimary: Color(0xFF2C221E),
      textSecondary: Color(0xFF57534E),
      textMuted: Color(0xFF78716C),
      primaryAmber: Color(0xFFB45309),
      successEmerald: Color(0xFF047857),
      // Eski 0xFF0369A1 (doygun mavi) sıcak kremle çatışıyordu — daha sakin,
      // yeşile yakın bir teal'e çekildi.
      infoTeal: Color(0xFF0F766E),
      // Eski 0xFF4338CA (canlı mor-mavi) aynı sebeple, tozlu/sakin bir
      // erguvan tonuna çekildi.
      cognitiveIndigo: Color(0xFF6D5A8C),
      dangerRed: Color(0xFFB91C1C),
      // Koyu, sıcak kahve/mürekkep tonu — krem/bej sekme zemininde en
      // yüksek okunabilirlik, parşömen hissiyle de uyumlu.
      tabLabel: Color(0xFF3B2F1F),
      glassBlurSigma: 0.0,
      enableHeavyGlow: false,
    );
  }

  @override
  DraconicTheme copyWith({
    DevicePerformanceTier? performanceTier,
    bool? isDark,
    Color? background,
    Color? surfaceDark,
    Color? surfaceLight,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? primaryAmber,
    Color? successEmerald,
    Color? infoTeal,
    Color? cognitiveIndigo,
    Color? dangerRed,
    Color? tabLabel,
    double? glassBlurSigma,
    bool? enableHeavyGlow,
  }) {
    return DraconicTheme(
      performanceTier: performanceTier ?? this.performanceTier,
      isDark: isDark ?? this.isDark,
      background: background ?? this.background,
      surfaceDark: surfaceDark ?? this.surfaceDark,
      surfaceLight: surfaceLight ?? this.surfaceLight,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      primaryAmber: primaryAmber ?? this.primaryAmber,
      successEmerald: successEmerald ?? this.successEmerald,
      infoTeal: infoTeal ?? this.infoTeal,
      cognitiveIndigo: cognitiveIndigo ?? this.cognitiveIndigo,
      dangerRed: dangerRed ?? this.dangerRed,
      tabLabel: tabLabel ?? this.tabLabel,
      glassBlurSigma: glassBlurSigma ?? this.glassBlurSigma,
      enableHeavyGlow: enableHeavyGlow ?? this.enableHeavyGlow,
    );
  }

  // dart:ui'nin global lerpDouble'ına bağımlı olmamak için yerel bir
  // karşılığı burada tanımlıyoruz — isim çözümlemesiyle ilgili hiçbir
  // belirsizliğe yer bırakmaz.
  static double _lerpD(double a, double b, double t) => a + (b - a) * t;

  @override
  DraconicTheme lerp(ThemeExtension<DraconicTheme>? other, double t) {
    if (other is! DraconicTheme) return this;
    return DraconicTheme(
      performanceTier: t < 0.5 ? performanceTier : other.performanceTier,
      isDark: t < 0.5 ? isDark : other.isDark,
      background: Color.lerp(background, other.background, t)!,
      surfaceDark: Color.lerp(surfaceDark, other.surfaceDark, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primaryAmber: Color.lerp(primaryAmber, other.primaryAmber, t)!,
      successEmerald: Color.lerp(successEmerald, other.successEmerald, t)!,
      infoTeal: Color.lerp(infoTeal, other.infoTeal, t)!,
      cognitiveIndigo: Color.lerp(cognitiveIndigo, other.cognitiveIndigo, t)!,
      dangerRed: Color.lerp(dangerRed, other.dangerRed, t)!,
      tabLabel: Color.lerp(tabLabel, other.tabLabel, t)!,
      glassBlurSigma: _lerpD(glassBlurSigma, other.glassBlurSigma, t),
      enableHeavyGlow: t < 0.5 ? enableHeavyGlow : other.enableHeavyGlow,
    );
  }
}
