// ============================================================================
// DOSYA ADI: lib/auth_screen.dart
// AÇIKLAMA: Hesap Sistemi — e-posta/şifre ile Giriş Yap / Kayıt Ol ekranı.
// Ayarlar sheet'indeki "Hesap" satırından açılır (bkz. profile_screen.dart).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'core/auth/auth_service.dart';
import 'core/theme/draconic_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUpMode = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'E-posta ve şifre gerekli.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = _isSignUpMode
        ? await AuthService.instance.signUp(email: email, password: password)
        : await AuthService.instance.signIn(email: email, password: password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _errorMessage = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textPrimary,
        title: Text(
          _isSignUpMode ? 'Hesap Oluştur' : 'Giriş Yap',
          style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(PhosphorIcons.userBold, size: 56, color: theme.primaryAmber),
              const SizedBox(height: 12),
              Text(
                // P0: yanıltıcı vaat düzeltildi — hesap sistemi şu an SADECE
                // Premium üyelik durumunu cihazlar arasında taşıyor (bkz.
                // auth_service.dart: signUp/signIn yalnızca
                // EntitlementRepository.linkToAccount çağırıyor). Kelime
                // ilerlemesi, seri, rozetler vb. henüz cihaza özel — bunları
                // da senkronize ediyormuş gibi bir metin gerçek dışı bir
                // beklenti yaratıyordu.
                _isSignUpMode
                    ? 'Premium üyeliğin bu hesaba bağlansın, başka cihazlarda da seni bulsun.'
                    : 'Hesabınla giriş yap, Premium durumun senin peşinden gelsin.',
                style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 28),
              _buildField(
                theme: theme,
                controller: _emailController,
                label: 'E-posta',
                icon: PhosphorIcons.envelopeSimpleBold,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              _buildField(
                theme: theme,
                controller: _passwordController,
                label: 'Şifre',
                icon: PhosphorIcons.lockKeyBold,
                obscureText: true,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(color: theme.dangerRed, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primaryAmber,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          _isSignUpMode ? 'Hesap Oluştur' : 'Giriş Yap',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                            _isSignUpMode = !_isSignUpMode;
                            _errorMessage = null;
                          }),
                  child: Text(
                    _isSignUpMode ? 'Zaten hesabın var mı? Giriş yap' : 'Hesabın yok mu? Kayıt ol',
                    style: GoogleFonts.inter(color: theme.cognitiveIndigo, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required DraconicTheme theme,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.inter(color: theme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: theme.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: theme.textSecondary, size: 18),
        filled: true,
        fillColor: theme.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.primaryAmber, width: 1.5),
        ),
      ),
    );
  }
}
