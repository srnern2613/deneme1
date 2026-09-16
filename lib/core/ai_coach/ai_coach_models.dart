// ============================================================================
// DOSYA ADI: lib/core/ai_coach/ai_coach_models.dart
// AÇIKLAMA: Ejderha Rotası V2 — Faz 7. AI Koç sohbet mesajı modeli.
// ============================================================================

enum AiCoachRole { user, assistant }

class AiCoachMessage {
  final AiCoachRole role;
  final String content;
  final DateTime timestamp;

  AiCoachMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, String> toApiJson() => {
        'role': role == AiCoachRole.user ? 'user' : 'assistant',
        'content': content,
      };
}

/// AI Koç günlük ücretsiz kotası dolduğunda fırlatılır — ekran bunu
/// yakalayıp merkezi paywall'ı (EntitlementRepository.presentPaywall) açar.
class AiCoachQuotaExceededException implements Exception {}

/// Yapılandırma (Edge Function URL / anon key) hâlâ placeholder ise
/// fırlatılır — geliştirme/kurulum aşamasında sessiz ağ hatası yerine
/// anlamlı bir mesaj göstermek için.
class AiCoachNotConfiguredException implements Exception {}
