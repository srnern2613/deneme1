// ==============================================================
// habit_tracker_screen.dart
// --------------------------------------------------------------
// AKILLI HEDEF KONTROLLÜ & SENKRONİZE ALIŞKANLIK TAKİPÇİSİ
// ==============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HabitTrackerScreen extends StatefulWidget {
  const HabitTrackerScreen({super.key});

  @override
  State<HabitTrackerScreen> createState() => _HabitTrackerScreenState();
}

class _HabitTrackerScreenState extends State<HabitTrackerScreen> {
  int _todayPages = 0;
  int _todayMinutes = 0;

  final List<Map<String, dynamic>> _habits = [
    {
      'id': 'reading_goal',
      'title': 'Günün Kitap Okuma Hedefi',
      'category': 'Okuma',
      'icon': Icons.menu_book_rounded,
      'isCompleted': false,
      'streak': 7,
      'type': 'page_goal',
      'targetValue': 20,
    },
    {
      'id': 'flashcard_review',
      'title': 'Günün Kelime Kartlarını Tekrar Et',
      'category': 'Kelime / SRS',
      'icon': Icons.style_rounded,
      'isCompleted': false,
      'streak': 5,
      'type': 'manual',
      'targetValue': 1,
    },
    {
      'id': 'focus_habit',
      'title': '30 Dakika Odaklanmış Çalışma',
      'category': 'Gelişim',
      'icon': Icons.timer_outlined,
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

  Future<void> _loadAndVerifyHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _getTodayKey();
    final pages = prefs.getInt('daily_pages_$todayKey') ?? 0;
    final minutes = prefs.getInt('daily_minutes_$todayKey') ?? 0;

    // Aktif sayfa hedefini genel Dashboard için kaydet
    final readingGoal = _habits.firstWhere(
      (h) => h['type'] == 'page_goal',
      orElse: () => {'targetValue': 20},
    );
    await prefs.setInt('active_reading_target_pages', readingGoal['targetValue'] as int);

    if (!mounted) return;
    setState(() {
      _todayPages = pages;
      _todayMinutes = minutes;

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
        habit['streak'] = (habit['streak'] as int) - 1;
      }
    });
  }

  // Mevcut Hedefi Düzenleme Dialogu
  void _showEditTargetDialog(Map<String, dynamic> habit) {
    final targetController = TextEditingController(text: habit['targetValue'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('${habit['title']} Güncelle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Günlük çıtanı yükselterek hedefini güncelleyebilirsin.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Yeni Hedef Sayısı',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            FilledButton(
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
              child: const Text('Güncelle'),
            ),
          ],
        );
      },
    );
  }

  // Yeni Alışkanlık Ekleme (Çakışma Korumalı)
  void _showAddHabitDialog() {
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '10');
    String selectedType = 'manual';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Yeni Alışkanlık Ekle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Alışkanlık Başlığı',
                        hintText: 'Örn: 15 Dk Podcast Dinle',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Takip Türü', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'manual', child: Text('✍️ Manuel Görev (Genel Hobi)')),
                        DropdownMenuItem(value: 'page_goal', child: Text('📖 Kitap Okuma (Sayfa)')),
                        DropdownMenuItem(value: 'minute_goal', child: Text('⏱️ Okuma Süresi (Dakika)')),
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
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: selectedType == 'page_goal' ? 'Hedef Sayfa Sayısı' : 'Hedef Süre (Dk)',
                          hintText: '10',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () {
                    // ÇAKIŞMA KONTROLÜ: Zaten otomatik bir hedef var mı?
                    final existingIndex = _habits.indexWhere((h) => h['type'] == selectedType && selectedType != 'manual');

                    if (existingIndex != -1) {
                      Navigator.pop(context); // Dialogu kapat

                      // Kullanıcıya rehberlik eden uyarı penceresi
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Hedef Zaten Mevcut'),
                            ],
                          ),
                          content: Text(
                            'Zaten aktif bir "${_habits[existingIndex]['title']}" (${_habits[existingIndex]['targetValue']} hedefli) bulunuyor. '
                            'Kafanın karışmaması için aynı türde birden fazla hedef yerine mevcut hedefini yükseltebilirsin.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Anladım'),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showEditTargetDialog(_habits[existingIndex]);
                              },
                              child: const Text('Mevcut Hedefi Düzenle'),
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
                          'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
                          'title': text,
                          'category': selectedType == 'page_goal'
                              ? 'Okuma'
                              : (selectedType == 'minute_goal' ? 'Zaman' : 'Genel'),
                          'icon': selectedType == 'page_goal'
                              ? Icons.menu_book_rounded
                              : (selectedType == 'minute_goal' ? Icons.timer_outlined : Icons.star_rounded),
                          'isCompleted': false,
                          'streak': 0,
                          'type': selectedType,
                          'targetValue': target,
                        });
                      });
                      _loadAndVerifyHabits();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final int completedCount = _habits.where((h) => h['isCompleted'] == true).length;
    final double progress = _habits.isNotEmpty ? completedCount / _habits.length : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hobi & Okuma Takibi'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddHabitDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni Hedef'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zinciri Kırma İlerleme Kartı
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.secondary, colors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bugünkü Seri',
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '$completedCount / ${_habits.length}',
                              style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    completedCount == _habits.length && _habits.isNotEmpty
                        ? 'Harika! Bugünkü tüm hedeflerini tamamladın! 🚀'
                        : (_todayPages > 0 || _todayMinutes > 0)
                            ? 'Bugün $_todayPages sayfa ($_todayMinutes dk) okundu. Zinciri kırma!'
                            : 'Zinciri kırma, bugünkü alışkanlıklarını tamamla.',
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Günlük Hedeflerim',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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
                      color: colors.error,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    setState(() {
                      _habits.removeAt(index);
                    });
                  },
                  child: Card(
                    child: ListTile(
                      onTap: type != 'manual' ? () => _showEditTargetDialog(habit) : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isCompleted ? Colors.green.withValues(alpha: 0.15) : colors.surfaceContainerHighest,
                        child: Icon(
                          habit['icon'] as IconData,
                          color: isCompleted ? Colors.green[700] : colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      title: Text(
                        habit['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted ? colors.onSurface.withValues(alpha: 0.5) : null,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            '${habit['category']}$progressHint',
                            style: TextStyle(fontSize: 12, color: colors.primary),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.amber[800]),
                          Text(
                            ' ${habit['streak']} Gün',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber[900]),
                          ),
                          if (type != 'manual') ...[
                            const SizedBox(width: 6),
                            Icon(Icons.edit_outlined, size: 13, color: colors.onSurface.withValues(alpha: 0.4)),
                          ],
                        ],
                      ),
                      trailing: Transform.scale(
                        scale: 1.1,
                        child: Checkbox(
                          value: isCompleted,
                          activeColor: Colors.green[600],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          onChanged: (_) => _toggleHabit(index),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 70),
          ],
        ),
      ),
    );
  }
}