// ============================================================================
// DOSYA ADI: lib/audio_handler.dart
// AÇIKLAMA: Android 13+ Kilit Ekranı ve Bildirim Çubuğu Medya Yöneticisi
//           + Bildirim Kapatıldığında/Kaydırıldığında Sesi Anında Keser
// ============================================================================

import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'audiobook_manager.dart';
import 'tts_service.dart';

class MyAudioHandler extends BaseAudioHandler {
  static late MyAudioHandler instance;

  /// AudioService arka plan servisini başlatır
  static Future<void> init() async {
    instance = await AudioService.init(
      builder: () => MyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.deneme1.audio',
        androidNotificationChannelName: 'Sesli Kitap Oynatıcı',
        androidNotificationIcon: 'mipmap/ic_launcher',
        // Duraklatıldığında bildirimin sabit kalmasını önler, sağa/sola kaydırmaya izin verir
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
      ),
    );
  }

  /// Android bildirim ve kilit ekranı arayüzünü günceller
  void updateMediaNotification({
    required String title,
    required String pageText,
    required bool isPlaying,
    String? coverUrl,
  }) {
    // Çirkin alt tireleri ve .pdf uzantılarını temizler
    final cleanTitle = title.replaceAll(RegExp(r'^[_\s.-]+'), '').replaceAll('.pdf', '');

    // Güvenli yerel görsel yolu
    final localArtUri = Uri.parse('android.resource://com.example.deneme1/mipmap/ic_launcher');

    mediaItem.add(MediaItem(
      id: 'audiobook_current',
      album: 'LingoFlux Sesli Kitap',
      title: cleanTitle,
      artist: pageText,
      artUri: (coverUrl != null && coverUrl.startsWith('file://'))
          ? Uri.parse(coverUrl)
          : localArtUri,
    ));

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {},
      androidCompactActionIndices: const [0, 1, 2],
      // KRİTİK GÜNCELLEME: Duraklatıldığında 'idle' moduna alarak Android'in bildirimi silmesine tam izin veriyoruz
      processingState: isPlaying ? AudioProcessingState.ready : AudioProcessingState.idle,
      playing: isPlaying,
    ));
  }

  /// Bildirim kartını sistemden tamamen kaldırır
  void stopMediaNotification() {
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  /// Bildirim sağa/sola kaydırılıp silindiğinde sesi donanımdan tamamen keser
  @override
  Future<void> onNotificationDeleted() async {
    await _killAudioCompletely();
  }

  /// Uygulama son uygulamalar listesinden kapatıldığında tetiklenir
  @override
  Future<void> onTaskRemoved() async {
    await _killAudioCompletely();
  }

  @override
  Future<void> stop() async {
    await _killAudioCompletely();
  }

  /// Sesi ve oynatıcı oturumunu tek hamlede sonlandıran güvenli metot
  Future<void> _killAudioCompletely() async {
    stopMediaNotification();
    unawaited(TtsService.instance.stop());
    await AudiobookManager.instance.closePlayer();
  }

  /// Bildirimdeki 'Play' butonuna basıldığında (0 ms gecikmeyle yanıt verir)
  @override
  Future<void> play() async {
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.ready,
      playing: true,
    ));
    AudiobookManager.instance.playFromNotification();
  }

  /// Bildirimdeki 'Pause' butonuna basıldığında (ANR kilidini engeller)
  @override
  Future<void> pause() async {
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    AudiobookManager.instance.pauseFromNotification();
  }

  /// Bildirimdeki 'Sonraki Sayfa' butonuna basıldığında
  @override
  Future<void> skipToNext() async {
    final manager = AudiobookManager.instance;
    if (manager.currentBook != null && manager.currentPage + 1 < manager.currentBook!.totalPages) {
      await manager.changePage(manager.currentPage + 1);
    }
  }

  /// Bildirimdeki 'Önceki Sayfa' butonuna basıldığında
  @override
  Future<void> skipToPrevious() async {
    final manager = AudiobookManager.instance;
    if (manager.currentBook != null && manager.currentPage > 0) {
      await manager.changePage(manager.currentPage - 1);
    }
  }
}