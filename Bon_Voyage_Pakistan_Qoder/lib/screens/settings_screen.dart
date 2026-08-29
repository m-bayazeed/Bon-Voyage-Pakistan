import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/theme_toggle.dart';
import 'login_screen.dart';

/// Settings & Account Preferences Screen for Bon Voyage Pakistan.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = 'Explorer';
  String _userEmail = 'user@bonvoyage.pk';
  int? _userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final name = await AuthService.getUserName() ?? 'Explorer';
    final email = await AuthService.getUserEmail() ?? 'user@bonvoyage.pk';
    final id = await AuthService.getUserId();

    if (mounted) {
      setState(() {
        _userName = name;
        _userEmail = email;
        _userId = id;
        _isLoading = false;
      });
    }
  }

  // ──────────────────────────────────────────
  // CHANGE USERNAME MODAL
  // ──────────────────────────────────────────

  void _showChangeUsernameDialog() {
    final controller = TextEditingController(text: _userName);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
          final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
          final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

          return AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Change Username',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: onBg),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your new display name. Your User ID and travel history remain unchanged.',
                    style: TextStyle(fontSize: 12.5, color: onVar, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: onBg),
                    decoration: InputDecoration(
                      labelText: 'New Username',
                      hintText: 'e.g. Ali Khan',
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.primary, size: 20),
                      filled: true,
                      fillColor: isDark
                          ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.5)
                          : AppTheme.lightSurfaceVariant.withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Username cannot be empty';
                      }
                      if (val.trim().length < 2) {
                        return 'Username must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: Text('Cancel', style: TextStyle(color: onVar, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setDialogState(() => isSaving = true);
                        final newName = controller.text.trim();
                        final result = await AuthService.updateUsername(newName);

                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }

                        if (result['success'] == true) {
                          if (mounted) {
                            setState(() => _userName = newName);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Username changed to "$newName"'),
                                  ],
                                ),
                                backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['message'] as String? ?? 'Failed to update username'),
                                backgroundColor: Colors.red[800],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────
  // CHANGE PASSWORD MODAL
  // ──────────────────────────────────────────

  void _showChangePasswordSheet() {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
          final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
          final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: onVar.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.lock_reset_rounded, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: onBg,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Authenticate with your current password before choosing a new one.',
                      style: TextStyle(fontSize: 12.5, color: onVar),
                    ),
                    const SizedBox(height: 20),

                    // 1. Current Password
                    TextFormField(
                      controller: currentPasswordCtrl,
                      obscureText: obscureCurrent,
                      style: TextStyle(fontSize: 14, color: onBg),
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: onVar,
                          ),
                          onPressed: () => setSheetState(() => obscureCurrent = !obscureCurrent),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.5)
                            : AppTheme.lightSurfaceVariant.withValues(alpha: 0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // 2. New Password
                    TextFormField(
                      controller: newPasswordCtrl,
                      obscureText: obscureNew,
                      style: TextStyle(fontSize: 14, color: onBg),
                      decoration: InputDecoration(
                        labelText: 'New Password (min 8 chars)',
                        prefixIcon: const Icon(Icons.lock_rounded, size: 20, color: AppTheme.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: onVar,
                          ),
                          onPressed: () => setSheetState(() => obscureNew = !obscureNew),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.5)
                            : AppTheme.lightSurfaceVariant.withValues(alpha: 0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (val.length < 8) {
                          return 'New password must be at least 8 characters';
                        }
                        if (val == currentPasswordCtrl.text) {
                          return 'New password must be different from current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // 3. Confirm New Password
                    TextFormField(
                      controller: confirmPasswordCtrl,
                      obscureText: obscureConfirm,
                      style: TextStyle(fontSize: 14, color: onBg),
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 20, color: AppTheme.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: onVar,
                          ),
                          onPressed: () => setSheetState(() => obscureConfirm = !obscureConfirm),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.5)
                            : AppTheme.lightSurfaceVariant.withValues(alpha: 0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (val != newPasswordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;

                                setSheetState(() => isSaving = true);
                                final result = await AuthService.changePassword(
                                  currentPassword: currentPasswordCtrl.text,
                                  newPassword: newPasswordCtrl.text,
                                );

                                if (sheetCtx.mounted) {
                                  Navigator.pop(sheetCtx);
                                }

                                if (result['success'] == true) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(Icons.lock_rounded, color: AppTheme.primary, size: 18),
                                            SizedBox(width: 8),
                                            Text('Password updated successfully'),
                                          ],
                                        ),
                                        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(result['message'] as String? ?? 'Failed to change password'),
                                        backgroundColor: Colors.red[800],
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Update Password',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────
  // LOGOUT CONFIRMATION DIALOG
  // ──────────────────────────────────────────

  void _showLogoutConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Log Out',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: onBg),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out? Your saved trip plans and scan history remain securely stored under your account.',
          style: TextStyle(fontSize: 13, color: onVar, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: onVar, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await AuthService.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProviderScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  // Back Button
                  Material(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: onBg),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Header Title
                  Text(
                    'Settings & Preferences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: onBg,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Settings Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Profile Banner Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primary.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: AppTheme.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Name, Email, User ID Badge
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _userName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: onBg,
                                            ),
                                          ),
                                        ),
                                        if (_userId != null) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'ID #$_userId',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _userEmail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: onVar,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── SECTION 1: ACCOUNT ──
                        _buildSectionHeader('ACCOUNT', onVar),
                        const SizedBox(height: 8),

                        _buildSettingsGroup(
                          isDark: isDark,
                          surface: surface,
                          children: [
                            _buildSettingsTile(
                              icon: Icons.person_outline_rounded,
                              title: 'Change Username',
                              subtitle: _userName,
                              onTap: _showChangeUsernameDialog,
                              onBg: onBg,
                              onVar: onVar,
                            ),
                            _buildDivider(isDark),
                            _buildSettingsTile(
                              icon: Icons.lock_outline_rounded,
                              title: 'Change Password',
                              subtitle: 'Update account password',
                              onTap: _showChangePasswordSheet,
                              onBg: onBg,
                              onVar: onVar,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── SECTION 2: APPEARANCE ──
                        _buildSectionHeader('APPEARANCE', onVar),
                        const SizedBox(height: 8),

                        _buildSettingsGroup(
                          isDark: isDark,
                          surface: surface,
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                  color: AppTheme.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'Theme Mode',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: onBg,
                                ),
                              ),
                              subtitle: Text(
                                isDark ? 'Dark Theme active' : 'Light Theme active',
                                style: TextStyle(fontSize: 12, color: onVar),
                              ),
                              trailing: ThemeToggle(
                                isDark: tp.isDark,
                                onToggle: () => tp.toggleTheme(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── SECTION 3: ACCOUNT ACTIONS ──
                        _buildSectionHeader('ACCOUNT ACTIONS', onVar),
                        const SizedBox(height: 8),

                        _buildSettingsGroup(
                          isDark: isDark,
                          surface: surface,
                          children: [
                            ListTile(
                              onTap: _showLogoutConfirmation,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.logout_rounded,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                              title: const Text(
                                'Log Out',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red,
                                ),
                              ),
                              subtitle: Text(
                                'Sign out of current account',
                                style: TextStyle(fontSize: 12, color: onVar),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color onVar) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: onVar,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({
    required bool isDark,
    required Color surface,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color onBg,
    required Color onVar,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: onBg,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: onVar),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: onVar,
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 54,
      endIndent: 16,
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.05),
    );
  }
}
