// ============================================================================
// DOSYA ADI: lib/core/entitlement/revenue_cat_config.dart
// AÇIKLAMA: Ejderha Rotası V2 — Faz 2. RevenueCat yapılandırma sabitleri.
//
// TODO: Aşağıdaki iki API anahtarını RevenueCat panelinden
// (https://app.revenuecat.com) alıp buraya yapıştırın:
//   Project Settings > API Keys > Public app-specific API keys
// Anahtarları asla bir git deposuna gerçek değerleriyle commit'lemeyin;
// ileride bunları --dart-define veya bir .env dosyasına taşımak isteyebilirsiniz.
//
// TODO: 'premiumEntitlementId' değeri, RevenueCat panelinde
// Entitlements bölümünde oluşturduğunuz kimlikle (ör. "premium")
// birebir eşleşmelidir.
// ============================================================================

class RevenueCatConfig {
  RevenueCatConfig._();

  static const String androidApiKey = 'YOUR_REVENUECAT_ANDROID_API_KEY';
  static const String iosApiKey = 'YOUR_REVENUECAT_IOS_API_KEY';

  static const String premiumEntitlementId = 'premium';
}
