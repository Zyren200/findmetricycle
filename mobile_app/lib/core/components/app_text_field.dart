import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Custom text input field
class AppTextField extends StatefulWidget {
  final String? label;
  final String placeholder;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final int maxLines;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const AppTextField({
    this.label,
    required this.placeholder,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    super.key,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: DesignTokens.spacing7),
            child: Text(
              widget.label!,
              style: const TextStyle(
                fontSize: DesignTokens.fontSize10,
                fontWeight: DesignTokens.fw500,
                color: DesignTokens.muted,
                letterSpacing: 0.8,
                fontFamily: DesignTokens.fontDmSans,
              ),
            ),
          ),
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          minLines: 1,
          maxLength: widget.maxLength,
          validator: widget.validator,
          onChanged: widget.onChanged,
          style: const TextStyle(
            fontSize: DesignTokens.fontSize14,
            color: DesignTokens.text,
            fontFamily: DesignTokens.fontDmSans,
          ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: const TextStyle(
              color: DesignTokens.muted,
              fontFamily: DesignTokens.fontDmSans,
            ),
            filled: true,
            fillColor: DesignTokens.bg3,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing14,
              vertical: DesignTokens.spacing12,
            ),
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radius),
              borderSide:
                  const BorderSide(color: DesignTokens.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radius),
              borderSide:
                  const BorderSide(color: DesignTokens.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radius),
              borderSide: const BorderSide(
                color: DesignTokens.accent,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radius),
              borderSide: const BorderSide(color: DesignTokens.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radius),
              borderSide: const BorderSide(color: DesignTokens.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
