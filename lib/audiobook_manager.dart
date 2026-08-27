// ============================================================================
// DOSYA ADI: lib/audiobook_manager.dart
// AÇIKLAMA: Generation Token (Hayalet Döngü İptali) & ValueNotifier Tabanlı Yönetici
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'book_model.dart';
import 'tts_service.dart';
import 'audio_handler.dart';

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
  int _currentPage = 0;
  bool _isPlaying = false;

  // KRİTİK 1: Sadece vurguyu dinleyen hafif ValueNotifier (PageView Rebuild'i engeller)
  final ValueNotifier<HighlightState?> activeHighlight = ValueNotifier<HighlightState?>(null);

  // KRİTİK 2: Generation Token - Eski hayalet okuma döngülerini anında öldürür
  int _sessionGeneration = 0;

  // KRİTİK 3: Regex önbelleği - Sayfalar tekrar tekrar parse edilmez
  final Map<int, List<String>> _sentenceCache = {};

  void Function(int pageIndex)? onPageTurned;

  Book? get currentBook => _currentBook;
  int get currentPage => _currentPage;
  bool get isPlaying => _isPlaying;
  bool get hasActiveSession => _currentBook != null;

  void startSession({
    required Book book,
    required int pageIndex,
    void Function(int pageIndex)? onPageTurnedCallback,
  }) {
    _currentBook = book;
    _currentPage = pageIndex;
    _isPlaying = true;
    _sentenceCache.clear();
    onPageTurned = onPageTurnedCallback;
    _sessionGeneration++; // Yeni oturum token'ı
    _updateNotification();
    notifyListeners();
    _readCurrentPage(_sessionGeneration);
  }

  void attachReaderCallback(void Function(int pageIndex)? callback) {
    onPageTurned = callback;
  }

  void playFromNotification() {
    if (_isPlaying || _currentBook == null) return;
    _isPlaying = true;
    _sessionGeneration++;
    _updateNotification();
    notifyListeners();
    _readCurrentPage(_sessionGeneration);
  }

  void pauseFromNotification() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _sessionGeneration++; // Eski döngüyü sonlandır
    activeHighlight.value = null;
    unawaited(TtsService.instance.stop());
    _updateNotification();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (!_isPlaying) {
      playFromNotification();
    } else {
      pauseFromNotification();
    }
  }

  Future<void> changePage(int newPage) async {
    if (_currentBook == null) return;
    _sessionGeneration++; // Sayfa değiştiği an önceki okuma döngüsünü öldür
    _currentPage = newPage.clamp(0, _currentBook!.totalPages - 1);
    activeHighlight.value = null;
    onPageTurned?.call(_currentPage);
    _updateNotification();
    notifyListeners();

    if (_isPlaying) {
      await TtsService.instance.stop();
      _readCurrentPage(_sessionGeneration);
    }
  }

  List<String> getPageSentences(int pageIndex) {
    if (_currentBook == null || pageIndex >= _currentBook!.totalPages) return [];
    if (_sentenceCache.containsKey(pageIndex)) return _sentenceCache[pageIndex]!;

    final raw = _currentBook!.pages.isNotEmpty ? _currentBook!.pages[pageIndex] : '';
    final clean = _normalizePdfText(raw);
    final regExp = RegExp(r'(?<=[.!?])\s+');
    final list = clean.split(regExp).where((s) => s.trim().length > 1).toList();
    _sentenceCache[pageIndex] = list;
    return list;
  }

  Future<void> _readCurrentPage(int token) async {
    if (_currentBook == null || _currentPage >= _currentBook!.totalPages || !_isPlaying) {
      return;
    }

    final pageIndex = _currentPage;
    final sentences = getPageSentences(pageIndex);

    if (sentences.isEmpty) {
      _advanceToNextPage(token);
      return;
    }

    for (int s = 0; s < sentences.length; s++) {
      // Token değiştiyse (sayfa değişti/duraklatıldı) bu döngüyü HEMEN terk et
      if (token != _sessionGeneration || !_isPlaying || _currentBook == null) {
        return;
      }

      final sentence = sentences[s];
      final wordsInSentence = sentence.split(' ').where((w) => w.isNotEmpty).toList();

      activeHighlight.value = HighlightState(
        pageIndex: pageIndex,
        sentenceIndex: s,
        wordIndexInSentence: 0,
      );

      await TtsService.instance.speakSentenceWithProgress(
        sentence,
        onProgress: (start, end, word) {
          if (token != _sessionGeneration || !_isPlaying) return;
          
          // Kelimenin cümle içindeki sırasını belirle
          final cleanTarget = word.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();
          for (int w = 0; w < wordsInSentence.length; w++) {
            final currentClean = wordsInSentence[w].replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase();
            if (currentClean == cleanTarget) {
              activeHighlight.value = HighlightState(
                pageIndex: pageIndex,
                sentenceIndex: s,
                wordIndexInSentence: w,
              );
              break;
            }
          }
        },
      );
    }

    if (token == _sessionGeneration && _isPlaying && _currentBook != null) {
      _advanceToNextPage(token);
    }
  }

  void _advanceToNextPage(int token) {
    if (_currentBook != null && _currentPage + 1 < _currentBook!.totalPages && _isPlaying) {
      _sessionGeneration++;
      _currentPage++;
      onPageTurned?.call(_currentPage);
      _updateNotification();
      notifyListeners();
      _readCurrentPage(_sessionGeneration);
    } else {
      stopSession();
    }
  }

  Future<void> stopSession() async {
    _sessionGeneration++;
    _isPlaying = false;
    activeHighlight.value = null;
    unawaited(TtsService.instance.stop());
    MyAudioHandler.instance.stopMediaNotification();
    notifyListeners();
  }

  Future<void> closePlayer() async {
    await stopSession();
    _currentBook = null;
    _sentenceCache.clear();
    notifyListeners();
  }

  void _updateNotification() {
    if (_currentBook != null) {
      MyAudioHandler.instance.updateMediaNotification(
        title: _currentBook!.title,
        pageText: 'Sayfa ${_currentPage + 1} / ${_currentBook!.totalPages}',
        isPlaying: _isPlaying,
      );
    }
  }

  String _normalizePdfText(String rawText) {
    String text = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'\n\s*\n+'), ' ');
    text = text.replaceAll('\n', ' ');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    return text.trim();
  }
}