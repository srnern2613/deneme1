// ============================================================================
// DOSYA ADI: lib/core/design_system/tr_case.dart
// AÇIKLAMA: UI/UX Düzeltme Listesi — P0-3: Dart'ın String.toUpperCase()'i
// locale-agnostic (İngilizce kuralı): 'i' harfini 'I' yapar, doğrusu 'İ'.
// "Kitaplık".toUpperCase() → "KITAPLIK" (yanlış) yerine bu extension
// "KİTAPLIK" (doğru) üretir. 'ı' zaten Dart'ın varsayılan toUpperCase()'inde
// doğru şekilde 'I' oluyor (ayrı bir kod noktası), dokunulmuyor.
//
// Kullanım: Türkçe metni büyük harfe çevirirken toUpperCase() yerine HER
// ZAMAN toUpperCaseTr() kullanılmalı — özellikle caps başlıklarda
// (RuneTitle vb.). İngilizce kelimeleri (öğrenilen hedef kelime, sınav
// kartları) büyütürken standart toUpperCase() kalmalı; onlar bu kuralın
// kapsamı dışında.
// ============================================================================

extension TrCase on String {
  /// Türkçe kurallarına göre büyük harfe çevirir: 'i' → 'İ' (nokta korunur).
  String toUpperCaseTr() {
    return replaceAll('i', 'İ').toUpperCase();
  }
}
