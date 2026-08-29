import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

/// Forgot password screen with email validation and visual identity.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _sent = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Simulate backend call — ready for real email integration.
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() {
      _sent = true;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVariant = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: onBg, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            width: 260,
            height: 260,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.1),
                    AppTheme.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: surface,
                            border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.12),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Reset Password',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: onBg,
                              fontSize: 28,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your email and we\'ll send you a link to reset your password.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: onVariant,
                              fontSize: 14,
                            ),
                      ),
                      const SizedBox(height: 36),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? surface.withOpacity(0.6) : surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: _sent ? _buildSuccessState() : _buildForm(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Remember your password? ',
                            style: TextStyle(color: onVariant, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            },
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Email Address',
            style: TextStyle(
              color: isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Email is required';
              final emailRegex = RegExp(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$');
              if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
              return null;
            },
            style: TextStyle(
              color: isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground,
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              hintText: 'explorer@example.com',
              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary, size: 22),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isLoading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.onPrimary),
                        ),
                      )
                    : const Row(
                        key: ValueKey('idle'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Send Reset Link'),
                          SizedBox(width: 8),
                          Icon(Icons.send_rounded, size: 18),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 40),
        ),
        const SizedBox(height: 18),
        Text(
          'Check your inbox',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.success),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ve sent a password reset link to ${_emailController.text.trim()}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
