// ==============================================================
// flashcards_exercise_screen.dart
// --------------------------------------------------------------
// TAM EKRAN KELİME ÇALIŞMA (SRS EGZERSİZ) MODÜLÜ
//
// Bu ekran:
// 1. Kaydedilen kelimeleri tam ekran kartlar halinde gösterir.
// 2. Karta dokununca İngilizce/Türkçe yüzünü çevirir.
// 3. Sağa kaydırınca "Bildim" (yeşil), sola kaydırınca "Tekrar" (kırmızı) sayar.
// 4. Egzersiz bitiminde başarı oranını ve özet skor tablosunu sunar.
// ==============================================================

// Flutter Material UI araçlarını içeri aktarıyoruz
import 'package:flutter/material.dart';

// Egzersiz ekranının ana widget sınıfı
class FlashcardsExerciseScreen extends StatefulWidget {
  // FlashcardsScreen'den gelen kart listesini karşılayan parametre
  final List<Map<String, dynamic>> cards;

  const FlashcardsExerciseScreen({super.key, required this.cards});

  @override
  State<FlashcardsExerciseScreen> createState() => _FlashcardsExerciseScreenState();
}

class _FlashcardsExerciseScreenState extends State<FlashcardsExerciseScreen> {
  // Kullanıcı kaydırdıkça listeden düşecek aktif kartlar listesi
  late List<Map<String, dynamic>> _remainingCards;

  // Skor sayaçları
  int _knownCount = 0;
  int _reviewCount = 0;
  int _initialTotal = 0;

  // Kartın arka yüzünün (Türkçe) açık olup olmadığını tutan durum
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    // Gelen kartların sırasını rastgele karıştırıyoruz
    _remainingCards = List.from(widget.cards)..shuffle();
    _initialTotal = _remainingCards.length;
  }

  // Sağa (Bildim) veya Sola (Tekrar Et) kaydırma mantığı
  void _handleCardDismiss(DismissDirection direction) {
    if (direction == DismissDirection.startToEnd) {
      // Sağa kaydırıldı -> Bildim
      setState(() {
        _knownCount++;
        _remainingCards.removeAt(0);
        _isFlipped = false;
      });
    } else {
      // Sola kaydırıldı -> Tekrar Et
      setState(() {
        _reviewCount++;
        _remainingCards.removeAt(0);
        _isFlipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelime Egzersizi'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _remainingCards.isEmpty
            // Tüm kartlar bittiğinde sonuç özetini çiz
            ? _buildCompletionView(colors, textStyles)
            // Kartlar devam ederken çalışma arayüzünü çiz
            : _buildExerciseView(colors, textStyles),
      ),
    );
  }

  // Egzersiz sürerken gösterilen kart alanı
  Widget _buildExerciseView(ColorScheme colors, TextTheme textStyles) {
    final currentCard = _remainingCards.first;
    final int currentIndex = _initialTotal - _remainingCards.length + 1;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Üst İlerleme ve Sayaç Alanı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kart $currentIndex / $_initialTotal',
                style: textStyles.titleMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green[600], size: 18),
                  const SizedBox(width: 4),
                  Text('$_knownCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Icon(Icons.replay_circle_filled_rounded, color: colors.error, size: 18),
                  const SizedBox(width: 4),
                  Text('$_reviewCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (currentIndex - 1) / _initialTotal,
            borderRadius: BorderRadius.circular(8),
            minHeight: 6,
          ),
          const SizedBox(height: 24),

          // Kaydırılabilir Flashcard
          Expanded(
            child: Dismissible(
              key: ValueKey(currentCard['id'] ?? currentCard['word']),
              direction: DismissDirection.horizontal,
              onDismissed: _handleCardDismiss,
              
              // Sağa kaydırma arka planı (Yeşil - Bildim)
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  color: Colors.green[600],
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.thumb_up_rounded, color: Colors.white, size: 36),
                    SizedBox(width: 12),
                    Text(
                      'BİLDİM',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),

              // Sola kaydırma arka planı (Kırmızı - Tekrar Et)
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  color: colors.error,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'TEKRAR ET',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.replay_rounded, color: Colors.white, size: 36),
                  ],
                ),
              ),

              // Kart Gövdesi (Dokununca çevrilir)
              child: GestureDetector(
                onTap: () => setState(() => _isFlipped = !_isFlipped),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Chip(
                          label: Text(
                            _isFlipped ? 'TÜRKÇE ANLAMI' : 'İNGİLİZCE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isFlipped ? colors.onPrimaryContainer : colors.onSecondaryContainer,
                            ),
                          ),
                          backgroundColor: _isFlipped ? colors.primaryContainer : colors.secondaryContainer,
                        ),
                        const Spacer(),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _isFlipped
                                ? (currentCard['meaning'] ?? '')
                                : (currentCard['word'] ?? ''),
                            key: ValueKey(_isFlipped),
                            textAlign: TextAlign.center,
                            style: textStyles.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _isFlipped ? colors.primary : colors.onSurface,
                            ),
                          ),
                        ),
                        const Spacer(),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app_outlined, size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
                            const SizedBox(width: 6),
                            Text(
                              _isFlipped ? 'Gizlemek için dokunun' : 'Anlamı görmek için dokunun',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Alt Manuel Butonlar
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(Icons.close_rounded, color: colors.error),
                  label: Text('Bilemedim', style: TextStyle(color: colors.error)),
                  onPressed: () => _handleCardDismiss(DismissDirection.endToStart),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                  label: const Text('Bildim', style: TextStyle(color: Colors.white)),
                  onPressed: () => _handleCardDismiss(DismissDirection.startToEnd),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Egzersiz Tamamlandı Ekranı
  Widget _buildCompletionView(ColorScheme colors, TextTheme textStyles) {
    final double successRate = _initialTotal > 0 ? (_knownCount / _initialTotal) * 100 : 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.green[100],
              child: Icon(Icons.emoji_events_rounded, size: 54, color: Colors.green[700]),
            ),
            const SizedBox(height: 24),
            Text('Tebrikler! 🎉', style: textStyles.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Bugünkü kelime egzersizini tamamladın.',
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildResultStat('Toplam', '$_initialTotal', colors.primary),
                  _buildResultStat('Bildim', '$_knownCount', Colors.green[600]!),
                  _buildResultStat('Tekrar', '$_reviewCount', colors.error),
                  _buildResultStat('Başarı', '%${successRate.toInt()}', Colors.amber[800]!),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Egzersizi Tekrarla'),
                onPressed: () {
                  setState(() {
                    _remainingCards = List.from(widget.cards)..shuffle();
                    _knownCount = 0;
                    _reviewCount = 0;
                    _isFlipped = false;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Kartlarıma Dön'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}