import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Redesigned signup screen with cinematic dark/light identity.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.signup(
      name: _nameController.text.trim(),
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
        _errorMessage = result['message'] as String? ?? 'Signup failed';
        _isLoading = false;
      });
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
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
          Positioned(
            top: -100,
            right: -100,
            width: 300,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondary.withOpacity(0.12),
                    AppTheme.secondary.withOpacity(0.0),
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_ios_rounded, color: onBg, size: 16),
                          label: Text('Back', style: TextStyle(color: onBg)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 24),
                      Text(
                        'Begin Your Journey',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: onBg,
                              fontSize: 28,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create an account to unlock AI-powered exploration.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: onVariant,
                              fontSize: 14,
                            ),
                      ),
                      const SizedBox(height: 32),
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
                                controller: _nameController,
                                label: 'Full Name',
                                hint: 'Ali Khan',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return 'Name is required';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
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
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _passwordController,
                                label: 'Password',
                                hint: '••••••••',
                                icon: Icons.lock_outline,
                                isPassword: true,
                                obscure: _obscurePassword,
                                onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Password is required';
                                  if (value.length < 8) return 'At least 8 characters';
                                  if (!value.contains(RegExp(r'[A-Z]'))) return 'One uppercase letter';
                                  if (!value.contains(RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]'))) {
                                    return 'One number or special character';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _confirmPasswordController,
                                label: 'Confirm Password',
                                hint: '••••••••',
                                icon: Icons.lock_outline,
                                isPassword: true,
                                obscure: _obscureConfirm,
                                onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Confirm your password';
                                  if (value != _passwordController.text) return 'Passwords do not match';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              // Password requirements hint
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: (isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant).withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PASSWORD REQUIREMENTS',
                                      style: TextStyle(
                                        color: onVariant,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _Requirement(text: 'At least 8 characters', met: _passwordController.text.length >= 8),
                                    _Requirement(
                                      text: 'One uppercase letter',
                                      met: _passwordController.text.contains(RegExp(r'[A-Z]')),
                                    ),
                                    _Requirement(
                                      text: 'One number or special character',
                                      met: _passwordController.text.contains(RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]')),
                                    ),
                                  ],
                                ),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 14),
                                _buildErrorBanner(),
                              ],
                              const SizedBox(height: 22),
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSignup,
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
                                              Text('Create Account'),
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
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: TextStyle(color: onVariant, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: _navigateToLogin,
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
    bool obscure = false,
    VoidCallback? onToggleObscure,
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
          obscureText: isPassword && obscure,
          validator: validator,
          onChanged: (_) => setState(() {}),
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
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                    onPressed: onToggleObscure,
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

class _Requirement extends StatelessWidget {
  final String text;
  final bool met;

  const _Requirement({required this.text, required this.met});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: met ? AppTheme.success : (isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: met
                  ? AppTheme.success
                  : (isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
