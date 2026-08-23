// ==============================================================
// habit_tracker_screen.dart
// --------------------------------------------------------------
// HOBİ, OKUMA VE ALIŞKANLIK TAKİP MODÜLÜ (STREAK & TRACKER)
// ==============================================================

import 'package:flutter/material.dart';

class HabitTrackerScreen extends StatefulWidget {
  const HabitTrackerScreen({super.key});

  @override
  State<HabitTrackerScreen> createState() => _HabitTrackerScreenState();
}

class _HabitTrackerScreenState extends State<HabitTrackerScreen> {
  // Örnek başlangıç alışkanlıkları
  final List<Map<String, dynamic>> _habits = [
    {
      'title': '20 Sayfa İngilizce Kitap Oku',
      'category': 'Okuma',
      'icon': Icons.menu_book_rounded,
      'isCompleted': true,
      'streak': 7,
    },
    {
      'title': 'Günün Kelime Kartlarını Tekrar Et',
      'category': 'Kelime / SRS',
      'icon': Icons.style_rounded,
      'isCompleted': false,
      'streak': 5,
    },
    {
      'title': '30 Dakika Odaklanmış Çalışma',
      'category': 'Gelişim',
      'icon': Icons.timer_outlined,
      'isCompleted': false,
      'streak': 3,
    },
  ];

  // Tamamlanma durumunu değiştirme
  void _toggleHabit(int index) {
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

  // Yeni Alışkanlık Ekleme Dialogu
  void _showAddHabitDialog() {
    final titleController = TextEditingController();
    final categoryController = TextEditingController(text: 'Genel');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Yeni Alışkanlık Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Alışkanlık Başlığı',
                  hintText: 'Örn: 15 Dk İngilizce Podcast Dinle',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  hintText: 'Örn: Okuma, Dil, Spor',
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
                final text = titleController.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    _habits.add({
                      'title': text,
                      'category': categoryController.text.trim().isEmpty ? 'Genel' : categoryController.text.trim(),
                      'icon': Icons.local_fire_department_rounded,
                      'isCompleted': false,
                      'streak': 0,
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Ekle'),
            ),
          ],
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
            // 1. BÖLÜM: Günlük İlerleme Kartı (Zinciri Kırma)
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

            // 2. BÖLÜM: Alışkanlık Listesi
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

                return Dismissible(
                  key: ValueKey(habit['title'] + index.toString()),
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
                            habit['category'],
                            style: TextStyle(fontSize: 12, color: colors.primary),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.amber[800]),
                          Text(
                            ' ${habit['streak']} Gün',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber[900]),
                          ),
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
            const SizedBox(height: 70), // FloatingActionButton alanı
          ],
        ),
      ),
    );
  }
}