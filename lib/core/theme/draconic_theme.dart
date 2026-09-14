import 'dart:ui';
import 'package:flutter/material.dart';

enum DevicePerformanceTier { high, low }

class DraconicTheme extends ThemeExtension<DraconicTheme> {
  final DevicePerformanceTier performanceTier;
  
  // Zemin ve Yüzeyler
  final Color background;
  final Color surfaceDark;
  final Color surfaceLight;
  final Color borderSubtle;

  // Vurgu Renkleri
  final Color primaryAmber;
  final Color successEmerald;
  final Color infoTeal;
  final Color cognitiveIndigo;
  final Color dangerRed;

  // Performansa Bağlı Değişkenler
  final double glassBlurSigma;
  final bool enableHeavyGlow;

  const DraconicTheme({
    required this.performanceTier,
    required this.background,
    required this.surfaceDark,
    required this.surfaceLight,
    required this.borderSubtle,
    required this.primaryAmber,
    required this.successEmerald,
    required this.infoTeal,
    required this.cognitiveIndigo,
    required this.dangerRed,
    required this.glassBlurSigma,
    required this.enableHeavyGlow,
  });

  factory DraconicTheme.highEnd() {
    return const DraconicTheme(
      performanceTier: DevicePerformanceTier.high,
      background: Color(0xFF070B14),
      surfaceDark: Color(0xFF0F172A),
      surfaceLight: Color(0xFF111827),
      borderSubtle: Color(0xFF1F2937),
      primaryAmber: Color(0xFFF59E0B),
      successEmerald: Color(0xFF10B981),
      infoTeal: Color(0xFF38BDF8),
      cognitiveIndigo: Color(0xFF6366F1),
      dangerRed: Color(0xFFEF4444),
      glassBlurSigma: 18.0,
      enableHeavyGlow: true,
    );
  }

  factory DraconicTheme.lowEnd() {
    return DraconicTheme.highEnd().copyWith(
      performanceTier: DevicePerformanceTier.low,
      glassBlurSigma: 0.0, // Düşük cihazlarda cam efekti kapatılır
      enableHeavyGlow: false,
    );
  }

  @override
  DraconicTheme copyWith({
    DevicePerformanceTier? performanceTier,
    Color? background,
    Color? surfaceDark,
    Color? surfaceLight,
    Color? borderSubtle,
    Color? primaryAmber,
    Color? successEmerald,
    Color? infoTeal,
    Color? cognitiveIndigo,
    Color? dangerRed,
    double? glassBlurSigma,
    bool? enableHeavyGlow,
  }) {
    return DraconicTheme(
      performanceTier: performanceTier ?? this.performanceTier,
      background: background ?? this.background,
      surfaceDark: surfaceDark ?? this.surfaceDark,
      surfaceLight: surfaceLight ?? this.surfaceLight,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      primaryAmber: primaryAmber ?? this.primaryAmber,
      successEmerald: successEmerald ?? this.successEmerald,
      infoTeal: infoTeal ?? this.infoTeal,
      cognitiveIndigo: cognitiveIndigo ?? this.cognitiveIndigo,
      dangerRed: dangerRed ?? this.dangerRed,
      glassBlurSigma: glassBlurSigma ?? this.glassBlurSigma,
      enableHeavyGlow: enableHeavyGlow ?? this.enableHeavyGlow,
    );
  }

  @override
  DraconicTheme lerp(ThemeExtension<DraconicTheme>? other, double t) {
    if (other is! DraconicTheme) return this;
    return DraconicTheme(
      performanceTier: t < 0.5 ? performanceTier : other.performanceTier,
      background: Color.lerp(background, other.background, t)!,
      surfaceDark: Color.lerp(surfaceDark, other.surfaceDark, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      primaryAmber: Color.lerp(primaryAmber, other.primaryAmber, t)!,
      successEmerald: Color.lerp(successEmerald, other.successEmerald, t)!,
      infoTeal: Color.lerp(infoTeal, other.infoTeal, t)!,
      cognitiveIndigo: Color.lerp(cognitiveIndigo, other.cognitiveIndigo, t)!,
      dangerRed: Color.lerp(dangerRed, other.dangerRed, t)!,
      glassBlurSigma: lerpDouble(glassBlurSigma, other.glassBlurSigma, t) ?? glassBlurSigma,
      enableHeavyGlow: t < 0.5 ? enableHeavyGlow : other.enableHeavyGlow,
    );
  }
}