// ============================================================================
// DOSYA ADI: lib/core/auth/auth_service.dart
// AÇIKLAMA: Hesap Sistemi — Firebase Authentication (e-posta/şifre) ince
// sarmalayıcısı. Giriş/kayıt/çıkışta RevenueCat kimliğini de
// EntitlementRepository.linkToAccount/unlinkAccount üzerinden hesaba
// bağlar/ayırır — Purchases.* asla doğrudan burada çağrılmaz (bkz.
// entitlement_repository.dart'taki kural).
// ============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../entitlement/entitlement_repository.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// google-services.json eklenip Firebase.initializeApp() başarılı
  /// olmadan true dönmez — UI (profile_screen.dart) Hesap ekranını açmadan
  /// önce bunu kontrol edip kullanıcıya net bir mesaj gösterir, çökme
  /// yerine.
  bool get isAvailable => Firebase.apps.isNotEmpty;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  /// Uygulama açılışında (main.dart) zaten oturum açık bir kullanıcı varsa
  /// RevenueCat kimliğini hesaba tekrar bağlamak için çağrılır. Firebase
  /// henüz kurulmadıysa (google-services.json eksikse) _auth erişimi hata
  /// fırlatabilir — bilerek burada yutuluyor ki main.dart'taki diğer servis
  /// başlatmaları (tema dahil) bundan etkilenmesin.
  Future<void> restoreAccountLinkIfNeeded() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        await EntitlementRepository.instance.linkToAccount(uid);
      }
    } catch (e) {
      debugPrint('AuthService.restoreAccountLinkIfNeeded hatası: $e');
    }
  }

  /// Başarılıysa null, hata varsa kullanıcıya gösterilecek Türkçe mesaj döner.
  Future<String?> signUp({required String email, required String password}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final uid = cred.user?.uid;
      if (uid != null) await EntitlementRepository.instance.linkToAccount(uid);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (e) {
      debugPrint('AuthService.signUp hatası: $e');
      return 'Beklenmeyen bir hata oluştu.';
    }
  }

  Future<String?> signIn({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      final uid = cred.user?.uid;
      if (uid != null) await EntitlementRepository.instance.linkToAccount(uid);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    } catch (e) {
      debugPrint('AuthService.signIn hatası: $e');
      return 'Beklenmeyen bir hata oluştu.';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await EntitlementRepository.instance.unlinkAccount();
  }

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Bu e-posta zaten kayıtlı.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'weak-password':
        return 'Şifre çok zayıf (en az 6 karakter olmalı).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı, lütfen biraz sonra tekrar dene.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok veya zayıf.';
      default:
        return 'Bir hata oluştu: ${e.message ?? e.code}';
    }
  }
}
