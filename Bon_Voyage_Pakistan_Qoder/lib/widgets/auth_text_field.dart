import 'package:flutter/material.dart';

/// A reusable, premium-styled text field for authentication screens.
///
/// Supports password visibility toggling, validation, prefix icons,
/// and consistent styling across Login and Signup screens.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: widget.controller,
        obscureText: widget.isPassword ? _obscure : false,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF0A2E22),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: const TextStyle(
              color: Color(0xFF6B8F7B), fontSize: 14, fontWeight: FontWeight.w500),
          hintStyle: const TextStyle(color: Color(0xFFA8C5B0), fontSize: 14),
          // Rounded borders with green accent
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD4E8D4), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1B7A3D), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFFF7FAF7),
          prefixIcon: Icon(
            widget.prefixIcon,
            color: const Color(0xFF1B7A3D),
            size: 22,
          ),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF6B8F7B),
                    size: 21,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}
