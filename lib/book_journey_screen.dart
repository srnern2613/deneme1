// ============================================================================
// DOSYA ADI: lib/book_journey_screen.dart
// AÇIKLAMA: Kitap İlerleme & Kelime Yolculuğu (Book Journey & Milestones) Ekranı
// GÖREVLER & DÜZELTMELER:
//   1. Dual-Track İlerleme: Reading Journey + Vocabulary Journey ayrımı.
//   2. Dinamik Milestone (Hedef) Motoru: Öğrenilen kelimelere göre dinamik görev.
//   3. Hızlı Kelime Özeti BottomSheet'i ve Dictionary Screen köprüsü.
//   4. NaN, sıfır kelime ve eksik kapak görselleri için %100 fallback koruması.
//   5. Semantik renk hiyerarşisi: Koyu zemin (#070B14), Turuncu (#F59E0B) Action CTA.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'database_helper.dart';
import 'dictionary_screen.dart';
import 'tts_service.dart';

class BookJourneyScreen extends StatefulWidget {
  final String bookTitle;
  final String? bookId;
  final String? author;
  final String? coverPath;
  final VoidCallback onContinueReading;

  const BookJourneyScreen({
    super.key,
    required this.bookTitle,
    this.bookId,
    this.author,
    this.coverPath,
    required this.onContinueReading,
  });

  @override
  State<BookJourneyScreen> createState() => _BookJourneyScreenState();
}

class _BookJourneyScreenState extends State<BookJourneyScreen> {
  Map<String, dynamic>? _journeyData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    TtsService.instance.initService();
    _loadJourneyData();
  }

  /// Veritabanından kitabın hem okuma hem kelime ilerlemesini çeker
  Future<void> _loadJourneyData() async {
    try {
      final data = await DatabaseHelper.instance.getBookJourneyData(
        bookTitle: widget.bookTitle,
        bookId: widget.bookId,
      );

      if (!mounted) return;
      setState(() {
        _journeyData = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Dinamik sonraki hedef (Milestone) mesajı üretir
  Map<String, String> _calculateNextMilestone(Map<String, dynamic> data) {
    final learningCount = data['learning_count'] as int? ?? 0;
    final totalWords = data['total_words'] as int? ?? 0;
    final lastChapter = data['last_chapter'] as String? ?? 'Bölüm 1';

    if (totalWords == 0) {
      return {
        'title': 'İlk Kelimeni Keşfet',
        'desc': 'Kitapta bilmediğin bir kelimenin üzerine dokunarak öğrenme serüvenini başlat.',
        'badge': '🎯 Başlangıç',
      };
    } else if (learningCount > 0) {
      final target = learningCount > 5 ? 5 : learningCount;
      return {
        'title': '$target Kelimede Ustalaş',
        'desc': 'Öğrenme havuzundaki kelimeleri tekrarlayarak "$lastChapter" kelimelerini kalıcı hafızaya taşı.',
        'badge': '🎯 Kelime Hedefi',
      };
    } else {
      return {
        'title': 'Okumaya Devam Et',
        'desc': 'Mevcut kelimelerini pekiştirdin! Yeni bölüme geçerek hazinene yeni kelimeler kat.',
        'badge': '🎯 Bölüm Sonu',
      };
    }
  }

  /// Kelime durum özetini açan BottomSheet
  void _showVocabularySummarySheet(Map<String, dynamic> data) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final total = data['total_words'] as int? ?? 0;
        final discovered = data['discovered_count'] as int? ?? 0;
        final learning = data['learning_count'] as int? ?? 0;
        final reviewing = data['reviewing_count'] as int? ?? 0;
        final familiar = data['familiar_count'] as int? ?? 0;
        final mastered = data['mastered_count'] as int? ?? 0;
        final boss = data['boss_count'] as int? ?? 0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kelime Dağılımı',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${widget.bookTitle} ($total Kelime)',
                        style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                  if (boss > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '👹 $boss Boss',
                        style: GoogleFonts.outfit(color: const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _buildSheetStatRow('🟣 Keşfedildi (Havuz Dışı)', '$discovered', const Color(0xFF38BDF8)),
              const SizedBox(height: 10),
              _buildSheetStatRow('🔵 Öğreniliyor (Aktif Pratik)', '$learning', const Color(0xFF818CF8)),
              const SizedBox(height: 10),
              _buildSheetStatRow('🟡 Tekrarda (Hata Yapılanlar)', '$reviewing', const Color(0xFFF59E0B)),
              const SizedBox(height: 10),
              _buildSheetStatRow('✨ Aşina (Ustalığa Yakın)', '$familiar', const Color(0xFFFBBF24)),
              const SizedBox(height: 10),
              _buildSheetStatRow('🟢 Mastered (Kalıcı Hafıza)', '$mastered', const Color(0xFF10B981)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DictionaryScreen(),
                      ),
                    );
                  },
                  icon: const Icon(PhosphorIcons.bookOpenTextBold, size: 18),
                  label: Text('TÜM KELİMELERİ GÖR', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.5)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetStatRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: const Color(0xFFE2E8F0), fontSize: 12.5, fontWeight: FontWeight.w600)),
          Text(value, style: GoogleFonts.outfit(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  String _formatReadingTime(int totalSeconds) {
    if (totalSeconds < 60) return '<1 dk';
    final mins = (totalSeconds / 60).round();
    if (mins < 60) return '$mins dk';
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    return '$hours sa ${remMins > 0 ? '$remMins dk' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B14),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Kitap Yolculuğu',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
            : _journeyData == null
                ? const Center(child: Text('İlerleme verisi bulunamadı.', style: TextStyle(color: Colors.white)))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- 1. KİTAP BİLGİ & KAPAK KARTI ---
                        _buildBookHeaderCard(),
                        const SizedBox(height: 20),

                        // --- 2. READING JOURNEY KATMANI ---
                        _buildReadingJourneySection(_journeyData!),
                        const SizedBox(height: 20),

                        // --- 3. VOCABULARY JOURNEY KATMANI ---
                        _buildVocabularyJourneySection(_journeyData!),
                        const SizedBox(height: 20),

                        // --- 4. SONRAKİ HEDEF (NEXT MILESTONE) ---
                        _buildNextMilestoneCard(_journeyData!),
                        const SizedBox(height: 20),

                        // --- 5. BU KİTAPTAN KEŞFEDİLEN KELİMELER ÖNİZLEMESİ ---
                        _buildSampleWordsSection(_journeyData!),
                        const SizedBox(height: 28),

                        // --- 6. DEVAM ET CTA BUTONU ---
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: const Color(0xFF070B14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context);
                              widget.onContinueReading();
                            },
                            icon: const Icon(PhosphorIcons.playBold, size: 18),
                            label: Text(
                              'KİTABA DEVAM ET',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildBookHeaderCard() {
    final author = widget.author ?? 'Bilinmeyen Yazar';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 78,
            decoration: BoxDecoration(
              color: const Color(0xFF070B14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            alignment: Alignment.center,
            child: const Icon(PhosphorIcons.bookBookmarkBold, color: Color(0xFF38BDF8), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.bookTitle,
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  author,
                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingJourneySection(Map<String, dynamic> data) {
    final readingPercentage = data['reading_percentage'] as int? ?? 0;
    final readingRatio = data['reading_ratio'] as double? ?? 0.0;
    final lastChapter = data['last_chapter'] as String? ?? 'Bölüm 1';
    final totalReadSec = data['total_read_seconds'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(PhosphorIcons.bookOpenBold, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Text('Reading Journey', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                ],
              ),
              Text(
                '%$readingPercentage Okundu',
                style: GoogleFonts.outfit(color: const Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: readingRatio,
              minHeight: 8,
              backgroundColor: const Color(0xFF070B14),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniInfoChip(PhosphorIcons.bookmarkSimpleBold, lastChapter, const Color(0xFF818CF8)),
              _buildMiniInfoChip(PhosphorIcons.clockBold, _formatReadingTime(totalReadSec), const Color(0xFFFBBF24)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVocabularyJourneySection(Map<String, dynamic> data) {
    final total = data['total_words'] as int? ?? 0;
    final discovered = data['discovered_count'] as int? ?? 0;
    final learning = (data['learning_count'] as int? ?? 0) + (data['reviewing_count'] as int? ?? 0);
    final mastered = data['mastered_count'] as int? ?? 0;

    return GestureDetector(
      onTap: () => _showVocabularySummarySheet(data),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(PhosphorIcons.brainBold, color: Color(0xFF818CF8), size: 18),
                    const SizedBox(width: 8),
                    Text('Vocabulary Journey', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                  ],
                ),
                Row(
                  children: [
                    Text('Detaylar', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                    const Icon(PhosphorIcons.caretRightBold, color: Color(0xFF94A3B8), size: 14),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildVocabStatColumn('$discovered', 'Keşfedildi', const Color(0xFF38BDF8), '🟣'),
                Container(height: 28, width: 1, color: const Color(0xFF1F2937)),
                _buildVocabStatColumn('$learning', 'Öğreniliyor', const Color(0xFFF59E0B), '🟡'),
                Container(height: 28, width: 1, color: const Color(0xFF1F2937)),
                _buildVocabStatColumn('$mastered', 'Mastered', const Color(0xFF10B981), '🟢'),
              ],
            ),
            if (total == 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF070B14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '📖 Bu kitaptan henüz kelime eklemedin. Okurken bilmediğin kelimelere dokunarak biriktir!',
                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNextMilestoneCard(Map<String, dynamic> data) {
    final milestone = _calculateNextMilestone(data);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SONRAKİ HEDEF',
                style: GoogleFonts.outfit(color: const Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  milestone['badge']!,
                  style: GoogleFonts.outfit(color: const Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            milestone['title']!,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            milestone['desc']!,
            style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleWordsSection(Map<String, dynamic> data) {
    final sampleWords = data['sample_words'] as List<Map<String, dynamic>>? ?? [];
    if (sampleWords.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bu Kitaptan Öğrendiklerin',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sampleWords.map((card) {
            final word = card['word'] as String? ?? '';
            final state = card['learning_state'] as String? ?? 'LEARNING';
            Color chipColor = const Color(0xFF818CF8);
            if (state == 'MASTERED') chipColor = const Color(0xFF10B981);
            if (state == 'DISCOVERED') chipColor = const Color(0xFF38BDF8);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: chipColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(word, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 5),
                  CircleAvatar(radius: 3, backgroundColor: chipColor),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMiniInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildVocabStatColumn(String count, String label, Color color, String emoji) {
    return Column(
      children: [
        Text(count, style: GoogleFonts.outfit(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 9)),
            const SizedBox(width: 3),
            Text(label, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}