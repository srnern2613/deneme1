// ============================================================================
// DOSYA ADI: lib/mini_player.dart
// AÇIKLAMA: Modern, Cam Efektli Floating Mini Oynatıcı Barı (Global Audiobook Senkronlu)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audiobook_manager.dart';
import 'reader_screen.dart';

class GlobalMiniPlayer extends StatelessWidget {
  const GlobalMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AudiobookManager.instance,
      builder: (context, _) {
        final manager = AudiobookManager.instance;
        if (!manager.hasActiveSession) return const SizedBox.shrink();

        final book = manager.currentBook!;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF6366F1).withValues(alpha: 0.22),
                      const Color(0xFF131B2E),
                    ]
                  : [
                      const Color(0xFF818CF8).withValues(alpha: 0.16),
                      Colors.white,
                    ],
            ),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3D5B) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ReaderScreen(book: book),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(book.icon, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: manager.isPlaying ? const Color(0xFF10B981) : Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                manager.isPlaying
                                    ? 'Sesli Dinleniyor • Sayfa ${manager.currentPage + 1}/${book.totalPages}'
                                    : 'Duraklatıldı • Sayfa ${manager.currentPage + 1}/${book.totalPages}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        manager.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_filled_rounded,
                        color: const Color(0xFF6366F1),
                        size: 32,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        manager.togglePlayPause();
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        manager.closePlayer();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}