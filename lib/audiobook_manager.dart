// ============================================================================
// DOSYA ADI: lib/audiobook_manager.dart
// AÇIKLAMA: Pasifize Edilmiş ve mini_player uyumluluğu eklenmiş Audiobook Manager
// ============================================================================

import 'package:flutter/material.dart';
import 'book_model.dart';

class HighlightState {
  final int pageIndex;
  final int sentenceIndex;
  final int? wordIndexInSentence;

  HighlightState({
    required this.pageIndex,
    required this.sentenceIndex,
    this.wordIndexInSentence,
  });
}

class AudiobookManager extends ChangeNotifier {
  static final AudiobookManager instance = AudiobookManager._init();
  AudiobookManager._init();

  Book? _currentBook;
  
  // Analitik uyarısı giderildi: Alanlar 'final' yapıldı veya gereksizler temizlendi
  final int _currentPage = 0;
  final bool _isPlaying = false;

  final ValueNotifier<HighlightState?> activeHighlight = ValueNotifier<HighlightState?>(null);

  Book? get currentBook => _currentBook;
  int get currentPage => _currentPage;
  bool get isPlaying => _isPlaying;
  bool get hasActiveSession => false;

  void attachReaderCallback(void Function(int pageIndex)? callback) {}

  /// mini_player.dart dosyasındaki çağrı hatasını (undefined_method) çözen stub metot
  Future<void> togglePlayPause() async {}

  Future<void> closePlayer() async {
    _currentBook = null;
    notifyListeners();
  }
}