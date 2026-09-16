// ============================================================================
// DOSYA ADI: lib/core/ai_coach/ai_coach_config.dart
// AÇIKLAMA: Ejderha Rotası V2 — Faz 7. AI Koç için Serverless Lite yapılandırması.
//
// ÖNEMLİ: Buradaki edgeFunctionUrl ve supabaseAnonKey İSTEMCİDE saklanması
// güvenli olan PUBLIC değerlerdir (RevenueCat API anahtarı gibi). Asıl
// gizli olan LLM sağlayıcı anahtarı (ör. ANTHROPIC_API_KEY) hiçbir zaman
// uygulamaya gömülmez — yalnızca Supabase Edge Function'ın sunucu
// tarafındaki ortam değişkeni olarak durur (bkz. supabase/functions/ai-coach).
// ============================================================================

class AiCoachConfig {
  AiCoachConfig._();

  // TODO(Faz 7): Supabase projenizi kurduktan sonra Edge Function'ı deploy
  // edin (`supabase functions deploy ai-coach`) ve buraya o fonksiyonun
  // URL'sini girin. Örnek: https://xxxxxxxx.supabase.co/functions/v1/ai-coach
  static const String edgeFunctionUrl = 'YOUR_SUPABASE_EDGE_FUNCTION_URL';

  // TODO(Faz 7): Supabase projenizin Settings > API bölümündeki "anon
  // public" anahtarını buraya girin. Bu, Edge Function'ı çağırmak için
  // gereken herkese açık anahtardır — bir sır değildir.
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  /// Ücretsiz (Premium olmayan) kullanıcıların günde kaç kez AI Koç'a
  /// mesaj yazabileceği. Sunucu tarafında bir kullanıcı/kimlik doğrulama
  /// katmanı olmadığı için (mimari: Local-First + Serverless Lite,
  /// anonim cihaz kimliği) bu kota İSTEMCİ tarafında SharedPreferences ile
  /// takip edilir — RevenueCat'in kendi entitlement mantığıyla aynı ruhta.
  static const int freeDailyMessageLimit = 5;

  /// Yapılandırmanın hâlâ placeholder değerlerde olup olmadığını kontrol
  /// eder — geliştirme sırasında sessizce ağ hatası almak yerine kullanıcıya
  /// anlamlı bir uyarı göstermek için kullanılır.
  static bool get isConfigured =>
      edgeFunctionUrl != 'YOUR_SUPABASE_EDGE_FUNCTION_URL' &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
      edgeFunctionUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;
}
