// ============================================================================
// DOSYA ADI: lib/ai_coach_screen.dart
// AÇIKLAMA: Ejderha Rotası V2 — Faz 7. AI Koç (Ignis) sohbet ekranı.
// Mesajlar core/ai_coach/ai_coach_repository.dart üzerinden ince bir
// Supabase Edge Function proxy'sine gönderilir — uygulama hiçbir LLM API
// anahtarı taşımaz. Ücretsiz kullanıcılar günlük sınırlı, Premium
// kullanıcılar sınırsız mesaj hakkına sahiptir.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'core/ai_coach/ai_coach_repository.dart';
import 'core/ai_coach/ai_coach_models.dart';
import 'core/entitlement/entitlement_repository.dart';
import 'core/theme/draconic_theme.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiCoachMessage> _messages = [];

  bool _isSending = false;
  int _remainingFree = -1; // -1 = henüz yüklenmedi / sınırsız

  @override
  void initState() {
    super.initState();
    _messages.add(AiCoachMessage(
      role: AiCoachRole.assistant,
      content: 'Selam maceracı! Ben Ignis. Kelime, telaffuz ya da çalışma stratejisi hakkında ne sormak istersin?',
    ));
    _refreshQuota();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshQuota() async {
    final remaining = await AiCoachRepository.instance.getRemainingFreeMessages();
    if (!mounted) return;
    setState(() => _remainingFree = remaining);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    HapticFeedback.selectionClick();
    _inputController.clear();
    setState(() {
      _messages.add(AiCoachMessage(role: AiCoachRole.user, content: text));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final reply = await AiCoachRepository.instance.sendMessage(
        message: text,
        history: _messages,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(AiCoachMessage(role: AiCoachRole.assistant, content: reply));
        _isSending = false;
      });
      _scrollToBottom();
      _refreshQuota();
    } on AiCoachQuotaExceededException {
      if (!mounted) return;
      setState(() => _isSending = false);
      final unlocked = await EntitlementRepository.instance.presentPaywall();
      if (unlocked) {
        _refreshQuota();
      }
    } on AiCoachNotConfiguredException {
      if (!mounted) return;
      setState(() {
        _messages.add(AiCoachMessage(
          role: AiCoachRole.assistant,
          content: 'AI Koç henüz yapılandırılmadı — geliştirici tarafında Supabase Edge Function kurulumu tamamlanmalı (ai_coach_config.dart).',
        ));
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(AiCoachMessage(
          role: AiCoachRole.assistant,
          content: 'Şu an sana ulaşamıyorum, birazdan tekrar dener misin?',
        ));
        _isSending = false;
      });
      _scrollToBottom();
    }
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: _buildQuotaBadge()),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _buildTypingBubble();
                  }
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaBadge() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    if (_remainingFree < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFDE68A).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIcons.sparkleBold, color: Color(0xFFFDE68A), size: 12),
            const SizedBox(width: 4),
            Text('Sınırsız', style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontWeight: FontWeight.w800, fontSize: 11)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Text('$_remainingFree hak kaldı', style: GoogleFonts.outfit(color: theme.textSecondary, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }

  // EJDERHA ROTASI V2 — Görsel Entegrasyonu: tüm ekranda tek bir yerden
  // yönetilen Ignis avatarı. Eski 🐉 emoji placeholder'ının yerini,
  // assets/images/mascot/ignis_avatar_badge.png (yuvarlak rünik arkaplanlı) alıyor.
  Widget _buildIgnisAvatar({double size = 28}) {
    return ClipOval(
      child: Image.asset(
        'assets/images/mascot/ignis_avatar_badge.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        // P0-D: kaynak dosya 2MB'ın üzerinde (yüksek çözünürlüklü);
        // cacheWidth/cacheHeight vermeden gereksiz tam-çözünürlük decode'u
        // yapılıyordu — gösterilen boyuta (size) göre cache verildi.
        cacheWidth: (size * MediaQuery.of(context).devicePixelRatio).round(),
        cacheHeight: (size * MediaQuery.of(context).devicePixelRatio).round(),
      ),
    );
  }

  Widget _buildMessageBubble(AiCoachMessage message) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    final bool isUser = message.role == AiCoachRole.user;
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFFF59E0B).withValues(alpha: 0.18) : theme.surfaceDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16).copyWith(
          bottomRight: isUser ? const Radius.circular(4) : null,
          bottomLeft: !isUser ? const Radius.circular(4) : null,
        ),
        border: Border.all(color: isUser ? const Color(0xFFF59E0B).withValues(alpha: 0.35) : theme.borderSubtle),
      ),
      child: Text(
        message.content,
        style: GoogleFonts.inter(color: theme.textPrimary, fontSize: 13.5, height: 1.4),
      ),
    );

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }

    // Asistan mesajlarının solunda küçük bir Ignis avatarı — konuşmanın
    // kimden geldiğini emoji yerine görsel olarak belli eder.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildIgnisAvatar(size: 24),
          const SizedBox(width: 8),
          Flexible(child: bubble),
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildIgnisAvatar(size: 24),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.surfaceDark.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: const Radius.circular(4)),
              border: Border.all(color: theme.borderSubtle),
            ),
            child: const SizedBox(
              width: 20,
              height: 12,
              child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B)))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(top: BorderSide(color: theme.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style: GoogleFonts.inter(color: theme.textPrimary, fontSize: 13.5),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Ignis\'e bir şey sor...',
                hintStyle: GoogleFonts.inter(color: theme.textMuted, fontSize: 13),
                filled: true,
                fillColor: theme.surfaceLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), padding: const EdgeInsets.all(12)),
            onPressed: _isSending ? null : _sendMessage,
            icon: Icon(Icons.send_rounded, color: theme.background, size: 18),
          ),
        ],
      ),
    );
  }
}
