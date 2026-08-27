// ============================================================================
// DOSYA ADI: lib/tts_service.dart
// AÇIKLAMA: ANR Korumalı, Kesin Karakter/Kelime Callback'li Yerel TTS Motoru
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Seslendirmen profil ayarları (Pitch, Hız, Dil ve Ses ID)
class VoiceProfile {
  final String id;
  final String displayName;
  final String description;
  final String targetCode;
  final String locale;
  final double pitch;
  final double rate;

  const VoiceProfile({
    required this.id,
    required this.displayName,
    required this.description,
    required this.targetCode,
    this.locale = 'en-US',
    this.pitch = 1.0,
    this.rate = 0.45,
  });
}

class TtsService {
  static final TtsService instance = TtsService._init();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isInitialized = false;
  bool _isPlaying = false;
  double _currentRate = 0.45;

  // --------------------------------------------------------------------------
  // ÇÖZÜLEN SORUN (Ağ Gecikmesi & Kilitlenme):
  // '-network' uzantılı Google sesleri emulator veya zayıf ağlarda gecikmeye ve
  // MethodChannel kuyruğunun şişmesine yol açıyordu.
  // Çözüm: Çevrimdışı ve donanım hızlandırmalı '-local' profillerine geçildi.
  // --------------------------------------------------------------------------
  final List<VoiceProfile> _voiceProfiles = const [
    VoiceProfile(
      id: 'sarah',
      displayName: 'Sarah (Doğal Kadın)',
      description: 'Akıcı, berrak ve dengeli anlatım.',
      targetCode: 'en-us-x-sfg-local',
      locale: 'en-US',
      pitch: 1.0,
      rate: 0.45,
    ),
    VoiceProfile(
      id: 'james',
      displayName: 'James (Derin Erkek)',
      description: 'Tok, sakin ve sürükleyici ton.',
      targetCode: 'en-us-x-iol-local',
      locale: 'en-US',
      pitch: 0.9,
      rate: 0.45,
    ),
    VoiceProfile(
      id: 'ava',
      displayName: 'Ava (Modern Genç)',
      description: 'Dinamik, enerjik ve akıcı tonlama.',
      targetCode: 'en-us-x-tpf-local',
      locale: 'en-US',
      pitch: 1.1,
      rate: 0.48,
    ),
  ];

  late VoiceProfile _activeProfile;

  bool get isPlaying => _isPlaying;
  double get currentRate => _currentRate;
  List<VoiceProfile> get voiceProfiles => _voiceProfiles;
  VoiceProfile get activeProfile => _activeProfile;

  TtsService._init() {
    _activeProfile = _voiceProfiles.first;
  }

  Future<void> initService() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(_currentRate);
      await _flutterTts.setPitch(_activeProfile.pitch);
      await _flutterTts.setVolume(1.0);

      // iOS Arka plan ses kategorisi yapılandırması
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
      );

      // Metot çağrılarının iç içe girmesini önlemek için senkron await
      await _flutterTts.awaitSpeakCompletion(true);
      await applyProfile(_activeProfile);

      _isInitialized = true;
    } catch (e) {
      debugPrint('TTS Başlatma Hatası: $e');
    }
  }

  Future<void> applyProfile(VoiceProfile profile) async {
    _activeProfile = profile;
    try {
      await _flutterTts.setPitch(profile.pitch);
      final voices = await _flutterTts.getVoices;
      if (voices is List) {
        Map? matchedVoice;
        for (var v in voices) {
          if (v is Map && v['name'] != null) {
            final name = v['name'].toString().toLowerCase();
            if (name.contains(profile.id) || name == profile.targetCode.toLowerCase()) {
              matchedVoice = v;
              break;
            }
          }
        }

        matchedVoice ??= voices.firstWhere(
          (v) => (v['locale'] ?? '').toString().toLowerCase().contains('en-us'),
          orElse: () => null,
        );

        if (matchedVoice != null) {
          await _flutterTts.setVoice({
            'name': matchedVoice['name'].toString(),
            'locale': matchedVoice['locale'].toString(),
          });
          debugPrint('🎙️ Aktif TTS Sesi: ${profile.displayName} -> ${matchedVoice['name']}');
        }
      }
    } catch (e) {
      debugPrint('Ses profili atanırken hata: $e');
    }
  }

  Future<void> setSpeed(double rate) async {
    _currentRate = rate;
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> speakWord(String word) async {
    await initService();
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (cleanWord.isEmpty) return;

    await stop();
    await _flutterTts.speak(cleanWord);
  }

  // --------------------------------------------------------------------------
  // ÇÖZÜLEN SORUN (Tahmini Vurgu Gecikmesi & UI Dengesizliği):
  // Eski mimaride Future.delayed(200ms) ile tahmini kelime vurgusu yapılıyordu.
  // Çözüm: flutter_tts'in yerel 'setProgressHandler' motoru bağlanarak işletim
  // sisteminin okuduğu karakter konumu (start/end) milisaniyesinde UI'a aktarıldı.
  // --------------------------------------------------------------------------
  Future<void> speakSentenceWithProgress(
    String sentence, {
    required Function(int start, int end, String word) onProgress,
  }) async {
    await initService();
    if (sentence.trim().isEmpty) return;
    _isPlaying = true;

    _flutterTts.setProgressHandler((String text, int start, int end, String word) {
      onProgress(start, end, word);
    });

    await _flutterTts.speak(sentence.trim());
  }

  Future<void> stop() async {
    _isPlaying = false;
    try {
      // Dinleyici kuyruğunu boşalt ve motoru sustur
      _flutterTts.setProgressHandler((text, start, end, word) {});
      await _flutterTts.stop();
    } catch (_) {}
  }
}