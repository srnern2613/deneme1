// ============================================================================
// DOSYA ADI: lib/tts_service.dart
// AÇIKLAMA: 3 Seçenekli Amerikan Karakter Profili ve TTS Servisi
//
// MİMARİ VE ÇALIŞMA MANTIĞI:
// 1. VoiceProfile Modeli: Teknik kodları (en-us-x-sfg-network vb.) kullanıcı
//    dostu isim ve açıklamalara (Sarah, James, Ava) eşler.
// 2. 3 Amerikan Seçeneği: Farklı duygu durumları için 2 kadın, 1 erkek stüdyo sesi.
// 3. Fallback Güvencesi: Cihazda o an belirli bir kod bulunamazsa en yakın
//    en-US sesine otomatik bağlanır; çökme yaşanmaz.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Kullanıcıya gösterilecek ses karakter modeli
class VoiceProfile {
  final String id;          // Benzersiz profil kimliği
  final String displayName; // Kullanıcının gördüğü şık etiket
  final String description; // Karakterin tonlama özeti
  final String targetCode;  // Cihazdaki karşılık gelen teknik kod
  final String locale;

  VoiceProfile({
    required this.id,
    required this.displayName,
    required this.description,
    required this.targetCode,
    this.locale = 'en-US',
  });
}

class TtsService {
  static final TtsService instance = TtsService._init();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isInitialized = false;
  bool _isPlaying = false;
  double _currentRate = 0.45;

  // 3 AMERİKAN SES KARAKTERİ
  final List<VoiceProfile> _voiceProfiles = [
    VoiceProfile(
      id: 'sarah',
      displayName: 'Sarah',
      description: 'Doğal & Sıcak (Kadın)',
      targetCode: 'en-us-x-sfg-network',
    ),
    VoiceProfile(
      id: 'james',
      displayName: 'James',
      description: 'Tok & Net (Erkek)',
      targetCode: 'en-us-x-tpd-network',
    ),
    VoiceProfile(
      id: 'ava',
      displayName: 'Ava',
      description: 'Canlı & Akıcı (Kadın)',
      targetCode: 'en-us-x-tpc-network',
    ),
  ];

  late VoiceProfile _activeProfile;

  bool get isPlaying => _isPlaying;
  double get currentRate => _currentRate;
  List<VoiceProfile> get voiceProfiles => _voiceProfiles;
  VoiceProfile get activeProfile => _activeProfile;

  TtsService._init() {
    _activeProfile = _voiceProfiles.first; // Varsayılan: Sarah
  }

  // --------------------------------------------------------------------------
  // MOTOR İLK KURULUMU
  // --------------------------------------------------------------------------
  Future<void> initService() async {
    if (_isInitialized) return;

    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(_currentRate);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);

    // Varsayılan profili ata
    await applyProfile(_activeProfile);

    _flutterTts.setStartHandler(() => _isPlaying = true);
    _flutterTts.setCompletionHandler(() => _isPlaying = false);
    _flutterTts.setCancelHandler(() => _isPlaying = false);
    _flutterTts.setErrorHandler((_) => _isPlaying = false);

    _isInitialized = true;
  }

  // --------------------------------------------------------------------------
  // PROFİL SEÇME VE CİHAZLA EŞLEŞTİRME
  // --------------------------------------------------------------------------
  Future<void> applyProfile(VoiceProfile profile) async {
    _activeProfile = profile;
    
    try {
      final voices = await _flutterTts.getVoices;
      if (voices is List) {
        // Cihazdaki seslerden hedef koda tam veya kısmi eşleşen sesi bul
        Map? matchedVoice;
        for (var v in voices) {
          if (v is Map && v['name'] != null) {
            final name = v['name'].toString().toLowerCase();
            if (name == profile.targetCode.toLowerCase()) {
              matchedVoice = v;
              break;
            }
          }
        }

        // Tam kod bulunamazsa en-US içeren uygun bir sesi seç
        matchedVoice ??= voices.firstWhere(
          (v) => (v['locale'] ?? '').toString().toLowerCase().contains('en-us'),
          orElse: () => null,
        );

        if (matchedVoice != null) {
          await _flutterTts.setVoice({
            'name': matchedVoice['name'].toString(),
            'locale': matchedVoice['locale'].toString(),
          });
          debugPrint('🎙️ Aktif Profil: ${profile.displayName} -> ${matchedVoice['name']}');
        }
      }
    } catch (e) {
      debugPrint('Profil atanırken hata: $e');
    }
  }

  // --------------------------------------------------------------------------
  // HIZ AYARI
  // --------------------------------------------------------------------------
  Future<void> setSpeed(double rate) async {
    _currentRate = rate;
    await _flutterTts.setSpeechRate(rate);
  }

  // --------------------------------------------------------------------------
  // TEK KELİME SESLENDİRME
  // --------------------------------------------------------------------------
  Future<void> speakWord(String word) async {
    await initService();
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (cleanWord.isEmpty) return;

    await stop();
    await _flutterTts.speak(cleanWord);
  }

  // --------------------------------------------------------------------------
  // AUDIOBOOK: CANLI VURGULU OKUMA
  // --------------------------------------------------------------------------
  Future<void> speakTextWithHighlight(
    String text, {
    required Function(String currentWord, int startOffset, int endOffset) onProgress,
    required Function() onComplete,
  }) async {
    await initService();
    if (text.trim().isEmpty) return;

    await stop();

    _flutterTts.setProgressHandler((String text, int start, int end, String word) {
      onProgress(word, start, end);
    });

    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
      onComplete();
    });

    await _flutterTts.speak(text);
  }

  // --------------------------------------------------------------------------
  // SESİ SUSTURMA
  // --------------------------------------------------------------------------
  Future<void> stop() async {
    await _flutterTts.stop();
    _isPlaying = false;
  }
}