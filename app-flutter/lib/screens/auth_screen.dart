import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_alerts.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_form_field.dart';
import '../widgets/loading_overlay.dart';

enum AuthMode { login, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AuthMode _mode = AuthMode.login;
  bool _obscurePassword = true;
  bool _loading = false;

  bool get _isRegister => _mode == AuthMode.register;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setMode(AuthMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
  }

  Future<void> _submit() async {
    if (_loading) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isRegister && name.isEmpty) {
      await showAppAlert(
        context,
        title: 'Atenção',
        message: 'Informe seu nome completo.',
      );
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      await showAppAlert(
        context,
        title: 'Atenção',
        message: 'Informe um e-mail válido.',
      );
      return;
    }

    if (password.length < 6) {
      await showAppAlert(
        context,
        title: 'Atenção',
        message: 'A senha deve ter pelo menos 6 caracteres.',
      );
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isRegister) {
        await _authService.register(
          name: name,
          email: email,
          password: password,
        );
      } else {
        await _authService.signIn(email: email, password: password);
      }

      if (!mounted) return;
      _enterApp();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Erro',
        message: AuthService.messageFor(error),
      );
    } catch (_) {
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Erro',
        message: 'Não foi possível autenticar. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enterApp() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.addressInput);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Premium modern gradient background with abstract custom route lines
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.backgroundGradientStart,
                    AppColors.backgroundGradientEnd,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: CustomPaint(
                painter: const _MapRoutePainter(),
                child: Container(),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: size.width > 500 ? 420 : double.infinity,
                  ),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    radius: 20, // slightly more rounded for premium card feel
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Glow circle logo
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primaryGradientStart,
                                  AppColors.primaryGradientEnd,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.alt_route_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Unified title
                        const Text(
                          'Rota Otimizada',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textStrong,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRegister
                              ? 'Crie sua conta para começar a otimizar.'
                              : 'Organize seus endereços e encontre a melhor rota.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Form fields with premium prefix icons
                        if (_isRegister) ...[
                          TextField(
                            controller: _nameController,
                            autofillHints: const [AutofillHints.name],
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: appInputDecoration(
                              'Nome completo',
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                                color: AppColors.textMuted,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextField(
                          controller: _emailController,
                          autofillHints: const [AutofillHints.email],
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: appInputDecoration(
                            'E-mail',
                            prefixIcon: const Icon(
                              Icons.mail_outline_rounded,
                              color: AppColors.textMuted,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          autofillHints: [
                            _isRegister
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: appInputDecoration(
                            'Senha',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.textMuted,
                              size: 22,
                            ),
                          ).copyWith(
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 22,
                              ),
                              color: AppColors.textMuted,
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Primary Action Button (now automatically uses premium gradient/glow)
                        AppButton(
                          label: _isRegister ? 'Criar minha conta' : 'Entrar na conta',
                          icon: _isRegister ? Icons.person_add_alt_rounded : Icons.login_rounded,
                          onPressed: _loading ? null : _submit,
                        ),
                        const SizedBox(height: 24),
                        // Divider
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: AppColors.border.withValues(alpha: 0.5),
                                thickness: 1,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OU',
                                style: TextStyle(
                                  color: AppColors.textSubtle,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: AppColors.border.withValues(alpha: 0.5),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Editorial switch link
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  _setMode(
                                    _isRegister
                                        ? AuthMode.login
                                        : AuthMode.register,
                                  );
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'Roboto',
                              ),
                              children: [
                                TextSpan(
                                  text: _isRegister
                                      ? 'Já possui uma conta? '
                                      : 'Ainda não tem cadastro? ',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const TextSpan(
                                  text: 'Clique aqui',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            LoadingOverlay(
              text: _isRegister ? 'Criando conta...' : 'Entrando...',
            ),
        ],
      ),
    );
  }
}

/// Custom painter to draw subtle abstract route lines in the login background.
class _MapRoutePainter extends CustomPainter {
  const _MapRoutePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    // Route 1 (Dynamic curves representing route lines)
    final path1 = Path()
      ..moveTo(size.width * 0.1, size.height * 0.15)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.08,
        size.width * 0.35,
        size.height * 0.35,
      )
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.62,
        size.width * 0.8,
        size.height * 0.52,
      )
      ..quadraticBezierTo(
        size.width * 0.95,
        size.height * 0.48,
        size.width * 0.9,
        size.height * 0.78,
      );

    canvas.drawPath(path1, paint);

    // Node points on Route 1
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.15), 6.5, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.35), 7.5, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.52), 6.5, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.78), 8.5, dotPaint);

    // Route 2 (Secondary route in the bottom region)
    final path2 = Path()
      ..moveTo(size.width * 0.85, size.height * 0.12)
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.28,
        size.width * 0.65,
        size.height * 0.48,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.68,
        size.width * 0.2,
        size.height * 0.86,
      );

    canvas.drawPath(path2, paint);

    // Node points on Route 2
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.12), 6.5, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.48), 7.5, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.86), 8.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
