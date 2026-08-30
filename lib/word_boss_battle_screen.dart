// ============================================================================
// DOSYA ADI: lib/word_boss_battle_screen.dart
// AÇIKLAMA: 6 Turlu Bilişsel Word Boss Savaş Arenası
// TUR SIRALAMASI:
//   Round 1: Meaning (Anlam Seçme)
//   Round 2: Context (Cümle Tamamlama)
//   Round 3: Listening (Dinleme & Anlama)
//   Round 4: Spelling (Harf Harf Yazma)
//   Round 5: Book Context (Orijinal Kitap Cümlesi Boşluğu)
//   Final Round: Minimum İpucuyla Geri Çağırma (Flashcard Recall)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'database_helper.dart';
import 'tts_service.dart';
import 'xp_shop_service.dart';

class WordBossBattleScreen extends StatefulWidget {
  final Map<String, dynamic> bossCard;

  const WordBossBattleScreen({super.key, required this.bossCard});

  @override
  State<WordBossBattleScreen> createState() => _WordBossBattleScreenState();
}

class _WordBossBattleScreenState extends State<WordBossBattleScreen> {
  // Savaş tur kontrolü (0: Meaning, 1: Context, 2: Listening, 3: Spelling, 4: Book Context, 5: Final Recall)
  int _currentRound = 0;
  static const int _totalRounds = 6;

  // Boss Can Puanı (Her doğru turda azalır)
  double _bossHp = 1.0;

  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;

  // Çeldiriciler ve seçenek havuzu
  List<String> _currentOptions = [];
  String? _selectedOption;
  bool? _isOptionCorrect;

  // Spelling Modu için harf durumları
  List<String> _targetLetters = [];
  final List<String> _enteredLetters = [];
  List<String> _shuffledKeyboardLetters = [];

  // Final Flashcard Flip Durumu
  bool _isFinalFlipped = false;

  @override
  void initState() {
    super.initState();
    TtsService.instance.initService();
    _prepareRoundData();
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  String get _word => widget.bossCard['word'] as String? ?? '';
  String get _meaning => widget.bossCard['meaning'] as String? ?? '';
  int get _bossLevel => widget.bossCard['boss_level'] as int? ?? 1;
  int get _cardId => widget.bossCard['id'] as int? ?? 0;
  String get _contextSentence => (widget.bossCard['context_sentence'] as String? ?? '').trim();

  String get _bossTitle {
    switch (_bossLevel) {
      case 4:
        return 'LEGENDARY BOSS';
      case 3:
        return 'ELITE BOSS';
      case 2:
        return 'RIVAL';
      case 1:
      default:
        return 'TROUBLEMAKER';
    }
  }

  String get _bossSubtitle {
    switch (_bossLevel) {
      case 4:
        return 'Uzun süredir öğrenilemiyor ve direniyor!';
      case 3:
        return 'Farklı öğrenme modlarında direniyor!';
      case 2:
        return 'Bu kelime seni tekrar yakaladı.';
      case 1:
      default:
        return 'Bu kelime biraz direniyor.';
    }
  }

  Color get _bossThemeColor {
    switch (_bossLevel) {
      case 4:
        return const Color(0xFFEF4444); // Kırmızı
      case 3:
        return const Color(0xFFA855F7); // Mor
      case 2:
        return const Color(0xFFF59E0B); // Turuncu
      case 1:
      default:
        return const Color(0xFF38BDF8); // Cyan
    }
  }

  /// Mevcut turun gerektirdiği seçenek ve verileri hazırlar
  Future<void> _prepareRoundData() async {
    setState(() {
      _isLoading = true;
      _selectedOption = null;
      _isOptionCorrect = null;
      _isProcessing = false;
      _isFinalFlipped = false;
    });

    try {
      if (_currentRound == 0 || _currentRound == 1 || _currentRound == 2 || _currentRound == 4) {
        // Çeldiricileri çek ve seçenekleri karıştır
        final distractors = await DatabaseHelper.instance.getDistractorMeanings(
          correctWord: _word,
          correctMeaning: _meaning,
          count: 3,
        );

        final options = [_meaning, ...distractors]..shuffle();
        if (mounted) {
          setState(() {
            _currentOptions = options;
            _isLoading = false;
          });
        }

        // Dinleme turundaysa otomatik telaffuz et
        if (_currentRound == 2) {
          Future.delayed(const Duration(milliseconds: 350), () {
            TtsService.instance.speakWord(_word);
          });
        }
      } else if (_currentRound == 3) {
        // Spelling Turu: Harfleri hazırla (Boşlukları temizle)
        final cleanLetters = _word.toUpperCase().replaceAll(' ', '').split('');
        final shuffled = List<String>.from(cleanLetters)..shuffle();

        if (mounted) {
          setState(() {
            _targetLetters = cleanLetters;
            _enteredLetters.clear();
            _shuffledKeyboardLetters = shuffled;
            _isLoading = false;
          });
        }
      } else {
        // Final Recall Turu
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Savaş verisi yüklenirken hata oluştu.';
          _isLoading = false;
        });
      }
    }
  }

  void _handleOptionSelect(String option) {
    if (_isProcessing) return;
    _isProcessing = true;
    _selectedOption = option;
    final isCorrect = (option.trim() == _meaning.trim());
    _isOptionCorrect = isCorrect;

    if (isCorrect) {
      HapticFeedback.heavyImpact();
      _advanceBossProgress();
    } else {
      HapticFeedback.mediumImpact();
      _handleRoundFailure();
    }
  }

  void _handleSpellingKeyPress(String letter, int index) {
    if (_isProcessing || _enteredLetters.length >= _targetLetters.length) return;
    HapticFeedback.selectionClick();

    setState(() {
      _enteredLetters.add(letter);
      _shuffledKeyboardLetters.removeAt(index);
    });

    if (_enteredLetters.length == _targetLetters.length) {
      _isProcessing = true;
      final enteredWord = _enteredLetters.join('');
      final targetWord = _targetLetters.join('');

      if (enteredWord == targetWord) {
        HapticFeedback.heavyImpact();
        _advanceBossProgress();
      } else {
        HapticFeedback.mediumImpact();
        _handleRoundFailure();
      }
    }
  }

  void _resetSpellingLetters() {
    if (_isProcessing) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredLetters.clear();
      _shuffledKeyboardLetters = List<String>.from(_targetLetters)..shuffle();
    });
  }

  void _advanceBossProgress() {
    setState(() {
      _bossHp = (_bossHp - (1.0 / _totalRounds)).clamp(0.0, 1.0);
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_currentRound + 1 >= _totalRounds) {
        _handleBossVictory();
      } else {
        setState(() {
          _currentRound++;
        });
        _prepareRoundData();
      }
    });
  }

  Future<void> _handleBossVictory() async {
    // 1. Veritabanında boss_level'ı sıfırla, streak +1 ve interval = 3 yap
    await DatabaseHelper.instance.recordMultiModalResult(
      cardId: _cardId,
      isCorrect: true,
      mode: 'boss',
    );

    // 2. XP ve Ödül ver
    await XpShopService.instance.addXp(20).catchError((_) => 0);

    if (!mounted) return;
    _showVictoryDialog();
  }

  Future<void> _handleRoundFailure() async {
    // Soğuma süresi uygula (Kullanıcıyı boğmamak için)
    await DatabaseHelper.instance.recordBossFailureCooldown(_cardId);

    if (!mounted) return;
    _showDefeatDialog();
  }

  void _showVictoryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
        title: Column(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(
              'BOSS DEFEATED!',
              style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '"$_word"',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _meaning,
              style: GoogleFonts.outfit(color: const Color(0xFF38BDF8), fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF070B14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: Column(
                children: [
                  _buildRewardRow('🧠 Mastery Progress', '+1 Ustalık Katkısı', const Color(0xFF818CF8)),
                  const SizedBox(height: 8),
                  _buildRewardRow('⚡ Tecrübe Puanı', '+20 XP', const Color(0xFFF59E0B)),
                  const SizedBox(height: 8),
                  _buildRewardRow('⏳ Sonraki Tekrar', '3 gün sonra', const Color(0xFF94A3B8)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: Text('Lobiye Dön', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDefeatDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _bossThemeColor.withValues(alpha: 0.6), width: 2),
        ),
        title: Column(
          children: [
            const Text('👹', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(
              'Boss Hâlâ Ayakta!',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19),
            ),
          ],
        ),
        content: Text(
          'Bu kelime biraz zor görünüyor. Pes etme! Tekrarlarını tamamlayıp güçlendiğinde tekrar rövanşa çıkabilirsin.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1F2937)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, false);
                  },
                  child: Text('Daha Sonra', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _bossThemeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _currentRound = 0;
                      _bossHp = 1.0;
                    });
                    _prepareRoundData();
                  },
                  child: Text('Tekrar Dene', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8))),
        Text(value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B14),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIcons.swordBold, size: 14, color: _bossThemeColor),
                const SizedBox(width: 5),
                Text(
                  _bossTitle,
                  style: GoogleFonts.outfit(color: _bossThemeColor, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ],
            ),
            Text(
              'Tur ${_currentRound + 1} / $_totalRounds',
              style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Column(
                      children: [
                        // --- 1. BOSS CAN BAR & SEVİYE KARTI ---
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _bossThemeColor.withValues(alpha: 0.4), width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text('👹', style: TextStyle(fontSize: 20)),
                                      const SizedBox(width: 8),
                                      Text(
                                        _word,
                                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'HP: %${(_bossHp * 100).toInt()}',
                                    style: GoogleFonts.outfit(color: _bossThemeColor, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _bossSubtitle,
                                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: _bossHp,
                                  minHeight: 7,
                                  backgroundColor: const Color(0xFF070B14),
                                  valueColor: AlwaysStoppedAnimation<Color>(_bossThemeColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- 2. DİNAMİK TUR GÖVDESİ ---
                        Expanded(child: _buildCurrentRoundContent()),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildCurrentRoundContent() {
    switch (_currentRound) {
      case 0:
        return _buildMeaningRound();
      case 1:
        return _buildContextRound();
      case 2:
        return _buildListeningRound();
      case 3:
        return _buildSpellingRound();
      case 4:
        return _buildBookContextRound();
      case 5:
      default:
        return _buildFinalRecallRound();
    }
  }

  // ROUND 1: Meaning (Anlam Seçme)
  Widget _buildMeaningRound() {
    return Column(
      children: [
        Text(
          'ROUND 1: MEANING',
          style: GoogleFonts.outfit(color: const Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Text(
          'Kelimenin doğru Türkçe karşılığını seç:',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        ..._currentOptions.map((opt) => _buildOptionButton(opt)),
        const Spacer(),
      ],
    );
  }

  // ROUND 2: Context (Cümle Tamamlama)
  Widget _buildContextRound() {
    final sentence = _contextSentence.isNotEmpty
        ? _contextSentence.replaceAll(RegExp(RegExp.escape(_word), caseSensitive: false), '_____')
        : 'The concept of _____ is important for our daily study.';

    return Column(
      children: [
        Text(
          'ROUND 2: CONTEXT',
          style: GoogleFonts.outfit(color: const Color(0xFF818CF8), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Text(
            '“$sentence”',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: const Color(0xFFE2E8F0), fontSize: 14, fontStyle: FontStyle.italic),
          ),
        ),
        const Spacer(),
        ..._currentOptions.map((opt) => _buildOptionButton(opt)),
        const Spacer(),
      ],
    );
  }

  // ROUND 3: Listening (Dinleme & Anlama)
  Widget _buildListeningRound() {
    return Column(
      children: [
        Text(
          'ROUND 3: LISTENING',
          style: GoogleFonts.outfit(color: const Color(0xFFF59E0B), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.18),
            padding: const EdgeInsets.all(22),
          ),
          icon: const Icon(Icons.volume_up_rounded, size: 36, color: Color(0xFFF59E0B)),
          onPressed: () {
            HapticFeedback.selectionClick();
            TtsService.instance.speakWord(_word);
          },
        ),
        const SizedBox(height: 8),
        Text('Dinlemek için dokun', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
        const Spacer(),
        ..._currentOptions.map((opt) => _buildOptionButton(opt)),
        const Spacer(),
      ],
    );
  }

  // ROUND 4: Spelling (Harf Harf Yazma)
  Widget _buildSpellingRound() {
    return Column(
      children: [
        Text(
          'ROUND 4: SPELLING',
          style: GoogleFonts.outfit(color: const Color(0xFFA855F7), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        Text(
          _meaning,
          style: GoogleFonts.outfit(color: const Color(0xFF38BDF8), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        // Harf kutucukları
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: List.generate(_targetLetters.length, (index) {
            final hasLetter = index < _enteredLetters.length;
            return Container(
              width: 36,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasLetter ? const Color(0xFF1E1B4B) : const Color(0xFF111827),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasLetter ? const Color(0xFFA855F7) : const Color(0xFF1F2937),
                  width: 1.5,
                ),
              ),
              child: Text(
                hasLetter ? _enteredLetters[index] : '',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            );
          }),
        ),
        const Spacer(),
        // Klavye harfleri
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(_shuffledKeyboardLetters.length, (index) {
            final letter = _shuffledKeyboardLetters[index];
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () => _handleSpellingKeyPress(letter, index),
              child: Text(letter, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
            );
          }),
        ),
        const SizedBox(height: 12),
        if (_enteredLetters.isNotEmpty)
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF94A3B8)),
            label: Text('Harfleri Sıfırla', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
            onPressed: _resetSpellingLetters,
          ),
      ],
    );
  }

  // ROUND 5: Book Context (Kitaptaki Orijinal Cümle)
  Widget _buildBookContextRound() {
    final bookTitle = widget.bossCard['book_title'] as String? ?? 'Kitabım';
    final rawSentence = _contextSentence.isNotEmpty
        ? _contextSentence
        : 'You must pay attention to this word when reading the book.';
    final blankedSentence = rawSentence.replaceAll(RegExp(RegExp.escape(_word), caseSensitive: false), '______');

    return Column(
      children: [
        Text(
          'ROUND 5: BOOK CONTEXT ($bookTitle)',
          style: GoogleFonts.outfit(color: const Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: Text(
            '“$blankedSentence”',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: const Color(0xFFE2E8F0), fontSize: 14, fontStyle: FontStyle.italic),
          ),
        ),
        const Spacer(),
        ..._currentOptions.map((opt) => _buildOptionButton(opt)),
        const Spacer(),
      ],
    );
  }

  // FINAL ROUND: Minimum İpucuyla Geri Çağırma
  Widget _buildFinalRecallRound() {
    return Column(
      children: [
        Text(
          'FINAL ROUND: RECALL',
          style: GoogleFonts.outfit(color: const Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isFinalFlipped = !_isFinalFlipped);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _word,
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  if (_isFinalFlipped)
                    Text(
                      _meaning,
                      style: GoogleFonts.outfit(color: const Color(0xFF38BDF8), fontSize: 20, fontWeight: FontWeight.bold),
                    )
                  else
                    Text(
                      'Anlamı kontrol etmek için dokun',
                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_isFinalFlipped)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _handleRoundFailure,
                  child: Text('Hatırlayamadım', style: GoogleFonts.outfit(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _advanceBossProgress,
                  child: Text('Biliyorum!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildOptionButton(String option) {
    final isSelected = (_selectedOption == option);
    Color borderColor = const Color(0xFF1F2937);
    Color bgColor = const Color(0xFF111827);

    if (isSelected && _isOptionCorrect != null) {
      if (_isOptionCorrect == true) {
        borderColor = const Color(0xFF10B981);
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
      } else {
        borderColor = const Color(0xFFEF4444);
        bgColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          side: BorderSide(color: borderColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        onPressed: () => _handleOptionSelect(option),
        child: Text(
          option,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}