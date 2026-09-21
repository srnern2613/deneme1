// ============================================================================
// DOSYA ADI: lib/core/entitlement/entitlement_repository.dart
// AÇIKLAMA: Ejderha Rotası V2 — Faz 2. Merkezi Entitlement (hak sahipliği)
// katmanı. Kendi backend'imizde fatura doğrulama YAPMIYORUZ — RevenueCat
// SDK'sı App Store/Play Store makbuzlarını kendi sunucusunda doğrulayıp
// bize "bu kullanıcı premium mi" bilgisini veriyor. Auth/login akışı yok;
// RevenueCat cihaza bağlı anonim bir kullanıcı ID'si kendi kendine üretip
// yönetiyor (Purchases.configure'a appUserID vermiyoruz).
//
// Uygulama genelinde TEK doğruluk kaynağı burasıdır. Yeni kod asla
// doğrudan Purchases.* çağırmamalı, EntitlementRepository.instance
// üzerinden okumalı.
// ============================================================================

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'revenue_cat_config.dart';

class EntitlementRepository {
  static final EntitlementRepository instance = EntitlementRepository._init();
  EntitlementRepository._init();

  /// Canlı premium durumu — UI'ın dinleyebileceği tek kaynak.
  /// PaywallTrigger başta olmak üzere hiçbir widget bunun dışında bir
  /// "premium mi" kontrolü yapmamalı.
  final ValueNotifier<bool> isPremiumNotifier = ValueNotifier<bool>(false);

  /// Geliştirici Test Modu (flashcards_screen.dart → Arena Ayarları) açıkken
  /// TÜM Premium özellikleri yerel olarak açar — RevenueCat'e hiçbir şey
  /// yazılmaz, sadece [isPremium] bunu da hesaba katar. Mod kapatılınca
  /// otomatik olarak tekrar kilitlenir. `PaywallTrigger` bu notifier'ı da
  /// dinler.
  final ValueNotifier<bool> devTestOverrideNotifier = ValueNotifier<bool>(false);

  void setDevTestOverride(bool value) {
    devTestOverrideNotifier.value = value;
  }

  bool get isPremium => isPremiumNotifier.value || devTestOverrideNotifier.value;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await Purchases.setLogLevel(LogLevel.warn);

      final PurchasesConfiguration configuration;
      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(RevenueCatConfig.androidApiKey);
      } else if (Platform.isIOS) {
        configuration = PurchasesConfiguration(RevenueCatConfig.iosApiKey);
      } else {
        // Desteklenmeyen platform (web/masaüstü) — entitlement kontrolü
        // sessizce pasif kalır, isPremiumNotifier false'ta sabitlenir.
        _isInitialized = true;
        return;
      }

      await Purchases.configure(configuration);
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
      await refresh();
      _isInitialized = true;
    } catch (e) {
      debugPrint('EntitlementRepository init hatası: $e');
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    isPremiumNotifier.value = info.entitlements.active.containsKey(RevenueCatConfig.premiumEntitlementId);
  }

  /// Entitlement durumunu sunucudan yeniden okur. Satın alma sonrası
  /// presentPaywall() bunu zaten otomatik çağırır — çoğu ekranın bunu
  /// elle çağırmasına gerek yoktur.
  Future<void> refresh() async {
    try {
      final info = await Purchases.getCustomerInfo();
      _onCustomerInfoUpdated(info);
    } catch (e) {
      debugPrint('Entitlement yenileme hatası: $e');
    }
  }

  /// RevenueCat'in hazır paywall ekranını gösterir. Satın alma veya
  /// "restore purchases" başarılı olursa true döner ve isPremiumNotifier
  /// otomatik güncellenmiş olur — çağıran taraf ekstra bir yenileme
  /// yapmasına gerek kalmadan UI'ını (örn. bir onUnlocked callback ile)
  /// güncelleyebilir.
  Future<bool> presentPaywall() async {
    try {
      final result = await RevenueCatUI.presentPaywallIfNeeded(RevenueCatConfig.premiumEntitlementId);
      await refresh();
      return result == PaywallResult.purchased || result == PaywallResult.restored;
    } catch (e) {
      debugPrint('Paywall gösterilemedi: $e');
      return false;
    }
  }

  /// I-5 (App Store zorunluluğu): paywall açmadan, doğrudan "satın alımları
  /// geri yükle". Önceden bu yalnızca presentPaywall() içinde dolaylı olarak
  /// (RevenueCat'in kendi paywall UI'ı üzerinden) mümkündü — Profil'de ayrı
  /// bir buton için bağımsız bir yol gerekiyordu. Başarı/başarısızlık,
  /// isPremiumNotifier'ın son hâline bakılarak anlaşılır (true/false döner).
  Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      _onCustomerInfoUpdated(info);
      return isPremium;
    } catch (e) {
      debugPrint('Satın alımlar geri yüklenemedi: $e');
      return false;
    }
  }

  /// Hesap sistemi (Firebase Auth) girişinde çağrılır: RevenueCat'in cihaza
  /// bağlı anonim kimliğini, hesabın kalıcı kimliğine (Firebase UID) taşır
  /// — böylece Premium durumu cihaza değil, hesaba bağlı olur ve başka bir
  /// cihazda aynı hesapla girişte otomatik görünür. Bu dosyanın "yeni kod
  /// asla doğrudan Purchases.* çağırmamalı" kuralı gereği AuthService bunu
  /// doğrudan değil, buradan çağırır.
  Future<void> linkToAccount(String appUserId) async {
    try {
      final result = await Purchases.logIn(appUserId);
      _onCustomerInfoUpdated(result.customerInfo);
    } catch (e) {
      debugPrint('RevenueCat hesap bağlama hatası: $e');
    }
  }

  /// Hesaptan çıkışta çağrılır: RevenueCat kimliğini tekrar cihaza bağlı
  /// anonim kimliğe döndürür.
  Future<void> unlinkAccount() async {
    try {
      final info = await Purchases.logOut();
      _onCustomerInfoUpdated(info);
    } catch (e) {
      debugPrint('RevenueCat hesap ayırma hatası: $e');
    }
  }
}
