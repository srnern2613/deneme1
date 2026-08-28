// ============================================================================
// DOSYA ADI: lib/audio_handler.dart
// AÇIKLAMA: Pasifize Edilmiş Audio Handler (Boş Stub Sınıf)
// ============================================================================

import 'package:audio_service/audio_service.dart';

class MyAudioHandler extends BaseAudioHandler {
  static late MyAudioHandler instance;

  static Future<void> init() async {
    // Özellik geçici olarak pasifize edildiği için servis başlatımı boşa çıkarıldı
  }

  void updateMediaNotification({
    required String title,
    required String pageText,
    required bool isPlaying,
    String? coverUrl,
  }) {}

  void stopMediaNotification() {}

  @override
  Future<void> stop() async {}
}