// ============================================================================
// DOSYA ADI: lib/mini_player.dart
// AÇIKLAMA: ReaderScreen Doğrudan Çağrımlı Mini Oynatıcı
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'book_model.dart';
import 'reader_screen.dart';

class GlobalMiniPlayer extends StatelessWidget {
  final Book? activeBook;
  final VoidCallback? onPlayPause;
  final VoidCallback? onClose;

  const GlobalMiniPlayer({
    super.key,
    this.activeBook,
    this.onPlayPause,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (activeBook == null) return const SizedBox.shrink();

    final book = activeBook!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(book.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ReaderScreen(book: book),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                  Text(
                    'Sayfa ${book.currentPage + 1} / ${book.totalPages}',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(PhosphorIcons.xBold, size: 16, color: Color(0xFF94A3B8)),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}