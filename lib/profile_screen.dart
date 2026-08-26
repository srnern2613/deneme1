// ==============================================================
// profile_screen.dart
// --------------------------------------------------------------
// PROFİL VE DETAYLI OKUMA/HAFIZA İSTATİSTİKLERİ MERKEZİ
// ==============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'library_screen.dart';
import 'flashcards_screen.dart';
import 'habit_tracker_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _totalReadMinutes = 0;
  int _totalWordsExamined = 0;
  int _totalFlashcards = 0;
  final int _streakDays = 7;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final cards = await DatabaseHelper.instance.getFlashcards();

    if (!mounted) return;
    setState(() {
      _totalReadMinutes = prefs.getInt('stats_total_read_minutes') ?? 120;
      _totalWordsExamined = prefs.getInt('stats_total_words_examined') ?? 45;
      _totalFlashcards = cards.length;
    });
  }

  // Sayfa geçişlerinde akıcı haptic (titreşim) ve modern yönlendirme sağlar
  void _navigateTo(Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) => _loadProfileData());
  }

  // PRO / Abonelik Bilgilendirme Penceresi
  void _showProDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Text('🚀', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Text('PRO Üyelik'),
          ],
        ),
        content: const Text(
          'Sınırsız PDF/TXT kitabı yükleme, bulut yedekleme, gelişmiş SRS istatistikleri ve yapay zeka destekli akıllı sınav modülü yakında sizlerle!\n\nŞimdilik tüm temel özellikleri tamamen ücretsiz kullanabilirsiniz.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Harika!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil & İstatistikler', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kullanıcı Bilgi Kartı
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: const Text('👨‍💻', style: TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ahmet',
                          style: TextStyle(
                            color: colors.onPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Aktif Gelişim Serisi: $_streakDays Gün 🔥',
                          style: TextStyle(
                            color: colors.onPrimary.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Genel Başarı Özetin',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // İstatistik Grid Kartları (Tıklanabilir Yapıldı)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _buildStatCard(
                  title: 'Okuma Süresi',
                  value: '$_totalReadMinutes dk',
                  icon: Icons.timer_rounded,
                  color: Colors.blue,
                  isDark: isDark,
                  onTap: () => _navigateTo(const LibraryScreen()),
                ),
                _buildStatCard(
                  title: 'Kelime Havuzu',
                  value: '$_totalFlashcards Kart',
                  icon: Icons.style_rounded,
                  color: Colors.pink,
                  isDark: isDark,
                  onTap: () => _navigateTo(const FlashcardsScreen()),
                ),
                _buildStatCard(
                  title: 'İncelenen Kelime',
                  value: '$_totalWordsExamined Kelime',
                  icon: Icons.search_rounded,
                  color: Colors.teal,
                  isDark: isDark,
                  onTap: () => _navigateTo(const FlashcardsScreen()),
                ),
                _buildStatCard(
                  title: 'Başarı Serisi',
                  value: '$_streakDays Gün',
                  icon: Icons.local_fire_department_rounded,
                  color: Colors.orange,
                  isDark: isDark,
                  onTap: () => _navigateTo(const HabitTrackerScreen()),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // PRO Üyelik Tanıtım Banner (Tıklanabilir ve Etkileşimli)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _showProDialog,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🚀', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PRO Sürüme Geç',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sınırsız PDF yükle, bulut yedekleme ve AI destekli sınav modülünün kilidini aç.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF4F46E5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  } ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: color, size: 22),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}