// ============================================================================
// DOSYA ADI: lib/core/ai_coach/ai_coach_repository.dart
// AÇIKLAMA: Ejderha Rotası V2 — Faz 7. AI Koç istemcisi. Uygulama hiçbir
// zaman bir LLM API anahtarı taşımaz — mesajlar ince bir Supabase Edge
// Function proxy'sine (supabase/functions/ai-coach) gönderilir, gizli
// anahtar yalnızca orada, sunucu tarafında durur.
//
// Ücretsiz kullanıcılar için günlük mesaj kotası TAMAMEN İSTEMCİ
// tarafında (SharedPreferences) takip edilir — mimari zaten sunucu
// tarafında kullanıcı/kimlik doğrulama katmanı taşımıyor (Local-First +
// Serverless Lite, anonim cihaz kimliği). Premium kullanıcılar
// EntitlementRepository.isPremium üzerinden sınırsız erişir.
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../entitlement/entitlement_repository.dart';
import 'ai_coach_config.dart';
import 'ai_coach_models.dart';

class AiCoachRepository {
  AiCoachRepository._init();
  static final AiCoachRepository instance = AiCoachRepository._init();

  String _todayKey() {
    final now = DateTime.now();
    return 'ai_coach_usage_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// -1 = sınırsız (Premium). 0..limit = ücretsiz kullanıcının bugün kalan
  /// mesaj hakkı.
  Future<int> getRemainingFreeMessages() async {
    if (EntitlementRepository.instance.isPremium) return -1;
    final prefs = await SharedPreferences.getInstance();
    final usedToday = prefs.getInt(_todayKey()) ?? 0;
    return (AiCoachConfig.freeDailyMessageLimit - usedToday).clamp(0, AiCoachConfig.freeDailyMessageLimit);
  }

  Future<void> _incrementUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _todayKey();
    final usedToday = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, usedToday + 1);
  }

  /// AI Koç'a bir mesaj gönderir ve yanıtı döner.
  /// Fırlatabilir: [AiCoachQuotaExceededException], [AiCoachNotConfiguredException].
  Future<String> sendMessage({
    required String message,
    List<AiCoachMessage> history = const [],
  }) async {
    if (!AiCoachConfig.isConfigured) {
      throw AiCoachNotConfiguredException();
    }

    final bool isPremium = EntitlementRepository.instance.isPremium;
    if (!isPremium) {
      final remaining = await getRemainingFreeMessages();
      if (remaining <= 0) {
        throw AiCoachQuotaExceededException();
      }
    }

    // Son 10 mesajla sınırlı bağlam — hem proxy tarafında maliyeti hem de
    // istek boyutunu kontrol altında tutar.
    final trimmedHistory = history.length > 10 ? history.sublist(history.length - 10) : history;

    final response = await http.post(
      Uri.parse(AiCoachConfig.edgeFunctionUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AiCoachConfig.supabaseAnonKey}',
        'apikey': AiCoachConfig.supabaseAnonKey,
      },
      body: jsonEncode({
        'message': message,
        'history': trimmedHistory.map((m) => m.toApiJson()).toList(),
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('AI Koç şu anda yanıt veremiyor (kod: ${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final reply = (decoded['reply'] ?? '').toString().trim();
    if (reply.isEmpty) {
      throw Exception('AI Koç boş bir yanıt döndürdü.');
    }

    // Yalnızca istek başarıyla yanıtlandıktan SONRA kotayı düş — hata
    // durumunda kullanıcının hakkı boşa gitmesin.
    if (!isPremium) await _incrementUsage();

    return reply;
  }
}
