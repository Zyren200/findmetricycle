import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Text input in the Sunrise style: bold label above a tinted, rounded
/// field with an orange focus ring. Works inside a [Form] (validator).
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

  /// Shown under the field (red border) when the validator has no error of
  /// its own — e.g. a server response like "This email is not registered."
  final String? errorText;

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
    this.errorText,
    super.key,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: 1.5),
      );

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              widget.label!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: DesignTokens.fw800,
                color: DesignTokens.ink,
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
          cursorColor: DesignTokens.primaryBright,
          style: TextStyle(
            fontSize: 15,
            fontWeight: DesignTokens.fw600,
            color: DesignTokens.ink,
          ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            filled: true,
            fillColor: focused ? DesignTokens.surface : DesignTokens.surface2,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
            errorText: widget.errorText,
            errorMaxLines: 2,
            errorStyle: TextStyle(
                color: DesignTokens.sosText,
                fontSize: 13,
                fontWeight: DesignTokens.fw700),
            border: _border(DesignTokens.lineStrong),
            enabledBorder: _border(DesignTokens.lineStrong),
            focusedBorder: _border(DesignTokens.primaryBright),
            errorBorder: _border(DesignTokens.sos),
            focusedErrorBorder: _border(DesignTokens.sos),
          ),
        ),
      ],
    );
  }
}
