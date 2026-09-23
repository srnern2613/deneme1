// ============================================================================
// DOSYA ADI: lib/ai_coach_screen.dart
// AÇIKLAMA: AI Koç (Ignis) ekranı — HAZIR SORU modu.
//
// Serbest yazma şimdilik KAPALI: kullanıcı, kategorilere ayrılmış hazır
// sorulardan birini seçer ve cevap yerel olarak (ağ/kota/hata riski
// olmadan) gelir. Soru-cevap içeriği tek yerden yönetilir:
// core/ai_coach/coach_question_catalog.dart.
//
// Serbest sohbet ileride açılacaksa: AiCoachRepository (Supabase Edge
// Function istemcisi) ve LocalFaqResponder dosyaları olduğu gibi duruyor;
// bu ekrana tekrar bir giriş çubuğu eklemek yeterli.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'core/ai_coach/ai_coach_models.dart';
import 'core/ai_coach/coach_question_catalog.dart';
import 'core/branding/app_branding.dart';
import 'core/entitlement/entitlement_repository.dart';
import 'core/theme/draconic_theme.dart';

/// Sohbet listesindeki tek bir satır. [offerPremium] true olan asistan
/// mesajlarının altında "Evet, göster / Şimdilik değil" seçenekleri çıkar;
/// kullanıcı birini seçince [ctaHandled] true olur ve seçenekler kaybolur.
class _CoachEntry {
  final AiCoachMessage message;
  final bool offerPremium;
  bool ctaHandled;

  _CoachEntry(this.message, {this.offerPremium = false}) : ctaHandled = false;
}

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<_CoachEntry> _entries = [];

  bool _isAnswering = false;
  int _selectedCategory = 0;

  @override
  void initState() {
    super.initState();
    _entries.add(_CoachEntry(AiCoachMessage(
      role: AiCoachRole.assistant,
      content: 'Selam maceracı, ben Ignis! 🔥\n\n'
          'Uygulama, öğrenme sistemi ya da kendi ilerlemen hakkında merak ettiklerini aşağıdaki '
          'sorulardan seçebilirsin. Hangisiyle başlayalım?',
    )));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _addAssistant(String text, {bool offerPremium = false}) {
    _entries.add(_CoachEntry(
      AiCoachMessage(role: AiCoachRole.assistant, content: text),
      offerPremium: offerPremium,
    ));
  }

  Future<void> _ask(CoachQuestion question) async {
    if (_isAnswering) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entries.add(_CoachEntry(AiCoachMessage(role: AiCoachRole.user, content: question.text)));
      _isAnswering = true;
    });
    _scrollToBottom();

    CoachAnswer answer;
    try {
      // Kısa bir "düşünüyor" anı — cevap anında belirmesin, doğal hissettirsin.
      final results = await Future.wait<Object>([
        question.answer(),
        Future<Object>.delayed(const Duration(milliseconds: 650), () => true),
      ]);
      answer = results.first as CoachAnswer;
    } catch (_) {
      answer = const CoachAnswer('Bu bilgiyi şu an getiremedim. Birazdan tekrar sorar mısın?');
    }

    if (!mounted) return;
    setState(() {
      _addAssistant(answer.text, offerPremium: answer.offerPremium);
      _isAnswering = false;
    });
    _scrollToBottom();
  }

  Future<void> _onPremiumCta(_CoachEntry entry, bool wantsUpgrade) async {
    if (entry.ctaHandled) return;
    HapticFeedback.lightImpact();
    setState(() => entry.ctaHandled = true);

    if (!wantsUpgrade) {
      setState(() {
        _addAssistant('Tamamdır! Fikrini değiştirirsen bu soruyu tekrar sorman ya da kilitli bir modun '
            'üstüne dokunman yeterli. Şimdilik ücretsiz modlarla avımıza devam 🔥');
      });
      _scrollToBottom();
      return;
    }

    final unlocked = await EntitlementRepository.instance.presentPaywall();
    if (!mounted) return;
    setState(() {
      if (unlocked) {
        _addAssistant('Aramıza hoş geldin, Premium maceracı! 👑 Ters Test, Sadece Dinleme ve Hız Turu '
            'artık Arena\'da seni bekliyor. Serin de artık sınırsız kalkanla korunuyor.');
      } else {
        _addAssistant('Sorun değil! Premium\'a istediğin zaman buradan ya da kilitli bir modun üstüne '
            'dokunarak ulaşabilirsin.');
      }
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textPrimary),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIgnisAvatar(size: 26),
            const SizedBox(width: 8),
            Text('AI Koç Ignis', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: theme.textPrimary, fontSize: 16)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _entries.length + (_isAnswering ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _entries.length) return _buildThinkingBubble(theme);
                  return _buildEntry(theme, _entries[index]);
                },
              ),
            ),
            _buildQuestionPanel(theme),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Soru paneli (eski yazı çubuğunun yerinde)
  // --------------------------------------------------------------------------

  Widget _buildQuestionPanel(DraconicTheme theme) {
    final categories = CoachQuestionCatalog.categories;
    final category = categories[_selectedCategory];

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceDark.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: theme.borderSubtle)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _buildCategoryChip(theme, categories[i], i == _selectedCategory, () {
                if (i == _selectedCategory) return;
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = i);
              }),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.26),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: category.questions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _buildQuestionTile(theme, category.questions[i]),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.sparkleBold, size: 11, color: theme.textMuted),
              const SizedBox(width: 5),
              Text(
                'Serbest sohbet yakında açılıyor',
                style: GoogleFonts.inter(color: theme.textMuted, fontSize: 10.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(DraconicTheme theme, CoachCategory category, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? theme.primaryAmber.withValues(alpha: 0.16) : theme.surfaceLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? theme.primaryAmber.withValues(alpha: 0.6) : theme.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, size: 13, color: selected ? theme.primaryAmber : theme.textSecondary),
              const SizedBox(width: 6),
              Text(
                category.label,
                style: GoogleFonts.outfit(
                  color: selected ? theme.primaryAmber : theme.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionTile(DraconicTheme theme, CoachQuestion question) {
    final enabled = !_isAnswering;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: theme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? () => _ask(question) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(question.icon, size: 16, color: theme.primaryAmber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    question.text,
                    style: GoogleFonts.inter(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(PhosphorIcons.caretRightBold, size: 13, color: theme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Sohbet balonları
  // --------------------------------------------------------------------------

  // Tüm ekranda tek bir yerden yönetilen, yuvarlak rünik arkaplanlı avatar.
  Widget _buildIgnisAvatar({double size = 28}) {
    return ClipOval(
      child: Image.asset(
        'assets/images/mascot/ignis_avatar_badge.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Kaynak dosya yüksek çözünürlüklü — decode gösterilen boyuta göre.
        cacheWidth: (size * MediaQuery.of(context).devicePixelRatio).round(),
        cacheHeight: (size * MediaQuery.of(context).devicePixelRatio).round(),
      ),
    );
  }

  Widget _buildEntry(DraconicTheme theme, _CoachEntry entry) {
    final message = entry.message;
    final bool isUser = message.role == AiCoachRole.user;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
      decoration: BoxDecoration(
        color: isUser ? theme.primaryAmber.withValues(alpha: 0.16) : theme.surfaceDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16).copyWith(
          bottomRight: isUser ? const Radius.circular(4) : null,
          bottomLeft: !isUser ? const Radius.circular(4) : null,
        ),
        border: Border.all(color: isUser ? theme.primaryAmber.withValues(alpha: 0.35) : theme.borderSubtle),
      ),
      child: Text(
        message.content,
        style: GoogleFonts.inter(color: theme.textPrimary, fontSize: 13.5, height: 1.45),
      ),
    );

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }

    final showCta = entry.offerPremium && !entry.ctaHandled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildIgnisAvatar(size: 24),
              const SizedBox(width: 8),
              Flexible(child: bubble),
            ],
          ),
          if (showCta)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.primaryAmber,
                      foregroundColor: theme.background,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _onPremiumCta(entry, true),
                    icon: const Icon(PhosphorIcons.crownBold, size: 15),
                    label: Text('Evet, göster', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textSecondary,
                      side: BorderSide(color: theme.borderSubtle),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _onPremiumCta(entry, false),
                    child: Text('Şimdilik değil', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Cevap hazırlanırken: düşünen Ignis pozu + küçük yükleniyor göstergesi.
  Widget _buildThinkingBubble(DraconicTheme theme) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Image.asset(
            AppBranding.poseAsset('thinking'),
            width: 40,
            height: 40,
            fit: BoxFit.contain,
            cacheWidth: (40 * dpr).round(),
            errorBuilder: (context, error, stackTrace) => _buildIgnisAvatar(size: 24),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.surfaceDark.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: const Radius.circular(4)),
              border: Border.all(color: theme.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryAmber),
                ),
                const SizedBox(width: 8),
                Text('Ignis düşünüyor…', style: GoogleFonts.inter(color: theme.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
