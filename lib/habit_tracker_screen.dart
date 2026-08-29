// ============================================================================
// DOSYA ADI: lib/habit_tracker_screen.dart
// AÇIKLAMA: Faz 5/6 - Asenkron Yarış ve Çift Kayıt Korumalı Alışkanlık Takibi
// GÖREVLER & DÜZELTMELER:
//   1. Çift Tıklama Koruması (_isSaving): Alışkanlık eklemede mükerrer kayıt önlendi.
//   2. Güvenli Asenkron Yaşam Döngüsü: Tüm async adımlarda mounted denetimleri eklendi.
//   3. Haftalık Ateş Zinciri & Mağaza Senkronizasyonu Korundu.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'xp_shop_service.dart';
import 'streak_freeze_service.dart';
import 'shop_screen.dart';

class HabitTrackerScreen extends StatefulWidget {
  const HabitTrackerScreen({super.key});

  @override
  State<HabitTrackerScreen> createState() => _HabitTrackerScreenState();
}

class _HabitTrackerScreenState extends State<HabitTrackerScreen> {
  int _todayPages = 0;
  int _todayMinutes = 0;
  int _currentStreak = 1;
  bool _hasFreezeShield = false;
  int _userGems = 50;
  int _userTotalXp = 100;

  // Son 7 günün seri tamamlama durumları
  List<bool> _last7DaysActive = [true, true, true, false, true, true, true];

  final List<Map<String, dynamic>> _habits = [
    {
      'id': 'reading_goal',
      'title': 'Günün Kitap Okuma Hedefi',
      'category': 'Okuma',
      'icon': PhosphorIcons.bookBookmarkBold,
      'isCompleted': false,
      'streak': 7,
      'type': 'page_goal',
      'targetValue': 20,
    },
    {
      'id': 'flashcard_review',
      'title': 'Günün Kelime Kartlarını Tekrar Et',
      'category': 'Kelime / SRS',
      'icon': PhosphorIcons.cardsBold,
      'isCompleted': false,
      'streak': 5,
      'type': 'manual',
      'targetValue': 1,
    },
    {
      'id': 'focus_habit',
      'title': '30 Dakika Odaklanmış Çalışma',
      'category': 'Gelişim',
      'icon': PhosphorIcons.timerBold,
      'isCompleted': false,
      'streak': 3,
      'type': 'manual',
      'targetValue': 1,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAndVerifyHabits();
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Asenkron Yarış Durumu (Race Condition) Korumalı Veri Yükleme
  Future<void> _loadAndVerifyHabits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _getTodayKey();
      final pages = prefs.getInt('daily_pages_$todayKey') ?? 0;
      final minutes = prefs.getInt('daily_minutes_$todayKey') ?? 0;
      final gems = await XpShopService.instance.getGemsBalance();
      final xp = await XpShopService.instance.getTotalXp();
      final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();

      // Asenkron işlem sonrası widget ağacının hayatta olup olmadığını denetle
      if (!mounted) return;

      final readingGoal = _habits.firstWhere(
        (h) => h['type'] == 'page_goal',
        orElse: () => {'targetValue': 20},
      );
      await prefs.setInt('active_reading_target_pages', readingGoal['targetValue'] as int);

      // Son 7 günün aktivite verilerini SharedPreferences'tan topla
      final now = DateTime.now();
      final List<bool> weekActivity = [];
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key = 'daily_pages_${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final readCount = prefs.getInt(key) ?? 0;
        weekActivity.add(readCount > 0);
      }

      if (!mounted) return;
      setState(() {
        _todayPages = pages;
        _todayMinutes = minutes;
        _userGems = gems;
        _userTotalXp = xp;
        _currentStreak = streakResult['streakDays'] ?? 1;
        _hasFreezeShield = streakResult['hasFreezeShield'] ?? false;
        _last7DaysActive = weekActivity;

        for (var habit in _habits) {
          final type = habit['type'] as String?;
          final target = (habit['targetValue'] as int?) ?? 1;

          if (type == 'page_goal') {
            habit['isCompleted'] = _todayPages >= target;
          } else if (type == 'minute_goal') {
            habit['isCompleted'] = _todayMinutes >= target;
          }
        }
      });
    } catch (_) {}
  }

  void _toggleHabit(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      final habit = _habits[index];
      final bool currentStatus = habit['isCompleted'] as bool;
      habit['isCompleted'] = !currentStatus;
      if (!currentStatus) {
        habit['streak'] = (habit['streak'] as int) + 1;
      } else {
        habit['streak'] = ((habit['streak'] as int) - 1).clamp(0, 9999);
      }
    });
  }

  void _showEditTargetDialog(Map<String, dynamic> habit) {
    HapticFeedback.lightImpact();
    final targetController = TextEditingController(text: habit['targetValue'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          title: Text(
            '${habit['title']} Güncelle',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Günlük çıtanı yükselterek hedefini güncelleyebilirsin.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Yeni Hedef Sayısı',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
              onPressed: () {
                final parsed = int.tryParse(targetController.text.trim());
                if (parsed != null && parsed > 0) {
                  setState(() {
                    habit['targetValue'] = parsed;
                  });
                  _loadAndVerifyHabits();
                  Navigator.pop(context);
                }
              },
              child: Text('Güncelle', style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAddHabitDialog() {
    HapticFeedback.selectionClick();
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '10');
    String selectedType = 'manual';
    bool isSaving = false; // Çift tıklama ve mükerrer kayıt kilidi

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              title: Text('Yeni Alışkanlık Ekle', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Alışkanlık Başlığı',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        hintText: 'Örn: 15 Dk Podcast Dinle',
                        hintStyle: const TextStyle(color: Color(0xFF475569)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Takip Türü', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'manual', child: Text('✍️ Manuel Görev')),
                        DropdownMenuItem(value: 'page_goal', child: Text('📖 Kitap Okuma (Sayfa)')),
                        DropdownMenuItem(value: 'minute_goal', child: Text('⏱️ Okuma Süresi (Dk)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedType = val);
                        }
                      },
                    ),
                    if (selectedType != 'manual') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: targetController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: selectedType == 'page_goal' ? 'Hedef Sayfa Sayısı' : 'Hedef Süre (Dk)',
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text('İptal', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8))),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
                  // Çift tıklama (Race Condition) koruması: Kayıt anında buton pasife çekilir
                  onPressed: isSaving ? null : () async {
                    if (isSaving) return;
                    setDialogState(() => isSaving = true);

                    final existingIndex = _habits.indexWhere((h) => h['type'] == selectedType && selectedType != 'manual');

                    if (existingIndex != -1) {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFF334155))),
                          title: Row(
                            children: [
                              const Icon(PhosphorIcons.infoBold, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text('Hedef Zaten Mevcut', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),),
                            ],
                          ),
                          content: Text(
                            'Zaten aktif bir "${_habits[existingIndex]['title']}" bulunuyor. Mevcut hedefini güncelleyebilirsin.',
                            style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text('Anladım', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8))),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showEditTargetDialog(_habits[existingIndex]);
                              },
                              child: Text('Düzenle', style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    final text = titleController.text.trim();
                    final parsed = int.tryParse(targetController.text.trim());
                    final target = (parsed != null && parsed > 0) ? parsed : 10;

                    if (text.isNotEmpty) {
                      setState(() {
                        _habits.add({
                          'id': 'custom_${DateTime.now().millisecondsSinceEpoch}_${_habits.length}',
                          'title': text,
                          'category': selectedType == 'page_goal'
                              ? 'Okuma'
                              : (selectedType == 'minute_goal' ? 'Zaman' : 'Genel'),
                          'icon': selectedType == 'page_goal'
                              ? PhosphorIcons.bookBookmarkBold
                              : (selectedType == 'minute_goal' ? PhosphorIcons.timerBold : PhosphorIcons.starBold),
                          'isCompleted': false,
                          'streak': 0,
                          'type': selectedType,
                          'targetValue': target,
                        });
                      });
                      await _loadAndVerifyHabits();
                      if (context.mounted) Navigator.pop(context);
                    } else {
                      setDialogState(() => isSaving = false);
                    }
                  },
                  child: Text('Ekle', style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openShop() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ShopScreen()),
    ).then((_) => _loadAndVerifyHabits());
  }

  @override
  Widget build(BuildContext context) {
    final int completedCount = _habits.where((h) => h['isCompleted'] == true).length;
    final double progress = _habits.isNotEmpty ? completedCount / _habits.length : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        onPressed: _showAddHabitDialog,
        icon: const Icon(PhosphorIcons.plusBold),
        label: Text('Yeni Hedef', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernHeader(),
              const SizedBox(height: 18),

              _buildStreakProtectionCard(),
              const SizedBox(height: 16),

              _buildWeeklyChainTracker(),
              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bugünkü İlerleme',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(PhosphorIcons.fireBold, color: Colors.orange, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '$completedCount / ${_habits.length}',
                                style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFF1F2937),
                        color: const Color(0xFF10B981),
                        minHeight: 7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      completedCount == _habits.length && _habits.isNotEmpty
                          ? 'Harika! Bugünkü tüm hedeflerini tamamladın! 🚀'
                          : (_todayPages > 0 || _todayMinutes > 0)
                              ? 'Bugün $_todayPages sayfa ($_todayMinutes dk) okundu. Zinciri kırma!'
                              : 'Zinciri kırma, bugünkü alışkanlıklarını tamamla.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              Text(
                'Günlük Hedeflerim',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _habits.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final habit = _habits[index];
                  final bool isCompleted = habit['isCompleted'];
                  final String type = habit['type'] ?? 'manual';
                  final int target = habit['targetValue'] ?? 1;

                  String progressHint = '';
                  if (type == 'page_goal') {
                    progressHint = ' • ($_todayPages/$target sayfa)';
                  } else if (type == 'minute_goal') {
                    progressHint = ' • ($_todayMinutes/$target dk)';
                  }

                  return Dismissible(
                    key: ValueKey(habit['id'] ?? habit['title']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(PhosphorIcons.trashBold, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        _habits.removeAt(index);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCompleted ? const Color(0xFF10B981).withValues(alpha: 0.35) : const Color(0xFF1F2937),
                          width: 1.4,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isCompleted ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Icon(
                                habit['icon'] as IconData,
                                color: isCompleted ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  habit['title'],
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                    color: isCompleted ? const Color(0xFF64748B) : Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${habit['category']}$progressHint',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF38BDF8)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(PhosphorIcons.fireBold, size: 12, color: Colors.orange),
                                    Text(
                                      ' ${habit['streak']} Gün',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                    if (type != 'manual') ...[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () => _showEditTargetDialog(habit),
                                        child: const Icon(PhosphorIcons.pencilSimpleBold, size: 13, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Transform.scale(
                            scale: 1.05,
                            child: Checkbox(
                              value: isCompleted,
                              activeColor: const Color(0xFF10B981),
                              checkColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              onChanged: (_) => _toggleHabit(index),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakProtectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _hasFreezeShield ? const Color(0xFF38BDF8).withValues(alpha: 0.5) : Colors.orange.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_hasFreezeShield ? const Color(0xFF38BDF8) : Colors.orange).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _hasFreezeShield ? PhosphorIcons.shieldCheckBold : PhosphorIcons.shieldWarningBold,
              color: _hasFreezeShield ? const Color(0xFF38BDF8) : Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_currentStreak Günlük Seri',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5),
                    ),
                    Text(
                      _hasFreezeShield ? '🛡️ Korumada' : '⚠️ Tehlikede',
                      style: GoogleFonts.outfit(
                        color: _hasFreezeShield ? const Color(0xFF38BDF8) : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _hasFreezeShield
                      ? 'Seri dondurucu aktif. Okumayı unutsan bile serin sıfırlanmaz.'
                      : 'Serini korumak için bugün oku veya mağazadan kalkan al.',
                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          if (!_hasFreezeShield) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _openShop,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Kalkan Al', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 11.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyChainTracker() {
    const List<String> dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Haftalık Zincir',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              Text(
                'Son 7 Gün',
                style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isActive = index < _last7DaysActive.length ? _last7DaysActive[index] : false;
              final isToday = index == 6;

              return Column(
                children: [
                  Text(
                    dayNames[index],
                    style: GoogleFonts.outfit(
                      color: isToday ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                      fontSize: 10.5,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.orange.withValues(alpha: 0.18) : const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isToday
                            ? const Color(0xFF38BDF8)
                            : (isActive ? Colors.orange.withValues(alpha: 0.5) : Colors.transparent),
                        width: isToday ? 1.8 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isActive ? PhosphorIcons.fireFill : PhosphorIcons.circleBold,
                        color: isActive ? Colors.orange : const Color(0xFF475569),
                        size: isActive ? 18 : 10,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alışkanlıklar',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            Text(
              'Günlük Hedefler & Seri Takibi',
              style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _openShop,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 15),
                    const SizedBox(width: 5),
                    Text('$_userGems', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIcons.lightningBold, color: Colors.orange, size: 15),
                  const SizedBox(width: 4),
                  Text('$_userTotalXp', style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}