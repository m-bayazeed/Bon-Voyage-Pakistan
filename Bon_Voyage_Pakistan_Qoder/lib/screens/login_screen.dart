import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

/// Redesigned login screen with cinematic dark/light identity.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
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
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMessage = result['message'] as String? ?? 'Login failed';
        _isLoading = false;
      });
    }
  }

  void _navigateToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  void _navigateToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
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
      body: Stack(
        children: [
          // Subtle ambient glow
          Positioned(
            top: -100,
            left: -100,
            width: 300,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.12),
                    AppTheme.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      // Logo
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          width: 110,
                          height: 110,
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
                      const SizedBox(height: 18),
                      Text(
                        'Bon Voyage Pakistan',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: onBg,
                              fontSize: 24,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Welcome Back!',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppTheme.primary,
                              fontSize: 28,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your AI Companion for Pakistan',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: onVariant,
                              fontSize: 14,
                            ),
                      ),
                      const SizedBox(height: 36),
                      // Glass card form
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email Address',
                                hint: 'explorer@example.com',
                                icon: Icons.email_outlined,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Email is required';
                                  final emailRegex = RegExp(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$');
                                  if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              _buildTextField(
                                controller: _passwordController,
                                label: 'Password',
                                hint: '••••••••',
                                icon: Icons.lock_outline,
                                isPassword: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Password is required';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _navigateToForgotPassword,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 36),
                                  ),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 12),
                                _buildErrorBanner(),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
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
                                              Text('Login to Dashboard'),
                                              SizedBox(width: 8),
                                              Icon(Icons.arrow_forward_rounded, size: 20),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: onVariant.withOpacity(0.2), thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'OR CONTINUE WITH',
                              style: TextStyle(
                                color: onVariant.withOpacity(0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: onVariant.withOpacity(0.2), thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Google button
                      SizedBox(
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Google sign-in coming soon!'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                          label: const Text(
                            'Google',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: onBg,
                            backgroundColor: isDark ? surface.withOpacity(0.5) : surface,
                            side: BorderSide(color: onVariant.withOpacity(0.15)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(color: onVariant, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: _navigateToSignup,
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    required String? Function(String?) validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          validator: validator,
          style: TextStyle(
            color: isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.primary, size: 22),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
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
    );
  }

}
