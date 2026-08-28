// ============================================================================
// DOSYA ADI: lib/design_lab_screen.dart
// AÇIKLAMA: Tüm Psikolojik Tetikleyiciler, Canlı Sayaçlar ve Efektlerle Donatılmış Nihai Prototip
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DesignLabScreen extends StatelessWidget {
  const DesignLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // --- ATMOSFERİK ARKAPLAN IŞIK SIZINTILARI ---
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.15), blurRadius: 100, spreadRadius: 50),
                ],
              ),
            ),
          ),
          Positioned(
            top: 250,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.08), blurRadius: 120, spreadRadius: 60),
                ],
              ),
            ),
          ),

          // --- ANA İÇERİK ---
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HUD & STATÜ PANELI (Artı Tetikleyicileri ile)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Elmas + Butonu (Mağaza Kancası)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 15),
                                const SizedBox(width: 5),
                                Text('599', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(color: const Color(0xFF38BDF8).withValues(alpha: 0.2), shape: BoxShape.circle),
                                  child: const Icon(PhosphorIcons.plusBold, color: Color(0xFF38BDF8), size: 10),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Seri + Butonu (Kalkan / Seri Artırma Kancası)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(PhosphorIcons.fireBold, color: Colors.orange, size: 15)
                                    .animate(onPlay: (c) => c.repeat(reverse: true))
                                    .scale(duration: 800.ms, begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
                                const SizedBox(width: 5),
                                Text('14 gün', style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), shape: BoxShape.circle),
                                  child: const Icon(PhosphorIcons.plusBold, color: Colors.orange, size: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827).withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                        ),
                        child: const Icon(PhosphorIcons.trophyBold, color: Color(0xFFF59E0B), size: 18),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 18),

                  // 2. ARENA / LİG KARTI
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF1E1B4B).withValues(alpha: 0.9), const Color(0xFF0F172A).withValues(alpha: 0.9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.6), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'SEZON 3 • 4 GÜN KALDI',
                                style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontWeight: FontWeight.w800, fontSize: 10),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(PhosphorIcons.trendUpBold, color: Color(0xFFEF4444), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Ligde 4. Sıradısın!',
                                  style: GoogleFonts.outfit(color: const Color(0xFFFCA5A5), fontWeight: FontWeight.w700, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '12. Arena - Kelime Ustası',
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '1. ile aranda 50 XP var, hemen geç!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: const LinearProgressIndicator(
                            value: 0.65,
                            minHeight: 10,
                            backgroundColor: Color(0xFF0F172A),
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. GÜNLÜK HEDEF & SANDIK (İlerleme Çubuklu)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(PhosphorIcons.giftBold, color: Color(0xFF34D399), size: 22)
                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                  .rotate(duration: 1000.ms, begin: -0.05, end: 0.05),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('Günlük Gizemli Sandık', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text('ÖDÜLLÜ', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('0 / 20 sayfa okundu (Açılmasına az kaldı!)', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11.5)),
                                ],
                              ),
                            ),
                            const Icon(PhosphorIcons.lockKeyBold, color: Color(0xFF34D399), size: 20),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Mini İlerleme Barı (Sandığın altındaki merak uyandırıcı detay)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 0.0,
                            minHeight: 5,
                            backgroundColor: Color(0xFF1F2937),
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4. HIZLI AKSİYON IZGARASI (Nabız Efektli Canlı Düello Kartı)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF1F2937)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(PhosphorIcons.swordBold, color: Color(0xFFEC4899), size: 20),
                                  ),
                                  // Nabız Efektli Canlı Rozet (FOMO)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                                    ),
                                    child: Text('CANLI', style: GoogleFonts.outfit(color: const Color(0xFFFCA5A5), fontWeight: FontWeight.w900, fontSize: 8.5)),
                                  ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 600.ms, begin: 0.5, end: 1.0),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Kelime Düellosu', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text('Hızlı Savaş', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF1F2937)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(PhosphorIcons.targetBold, color: Color(0xFF38BDF8), size: 20),
                              ),
                              const SizedBox(height: 12),
                              Text('Günlük Görev', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text('3 / 5 Tamamlandı', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 5. ANA ÇAĞRI BUTONU (CTA)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: const Color(0xFF0F172A),
                            elevation: 8,
                            shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(PhosphorIcons.lightningBold, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'HIZLI PRATİK BAŞLAT',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                              ),
                            ],
                          ),
                        ),
                      ).animate().scale(duration: 200.ms),
                      const SizedBox(height: 6),
                      Text(
                        '⚡ Hemen başla, +50 XP ve serini garantile!',
                        style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}