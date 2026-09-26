import "package:flutter/material.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";

/// Step 2 of the password-change flow — the OTP is the hard gate: the
/// backend rejects a wrong/expired code and leaves the password
/// untouched, so this page can only ever pop(true) after a real success.
class ChangePasswordOtpPage extends StatefulWidget {
  const ChangePasswordOtpPage({
    required this.confirm,
    this.maskedEmail,
    super.key,
  });

  final Future<bool> Function(String otp) confirm;
  final String? maskedEmail;

  @override
  State<ChangePasswordOtpPage> createState() => _ChangePasswordOtpPageState();
}

class _ChangePasswordOtpPageState extends State<ChangePasswordOtpPage> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isSubmitting = false;
  String? _error;

  String get _otpCode =>
      _otpControllers.map((controller) => controller.text).join();

  @override
  void dispose() {
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _otpCode;
    if (code.length != 6) {
      setState(() => _error = "Enter the 6-digit code sent to your email.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final success = await widget.confirm(code);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _error = "Invalid or expired code. Please try again.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.bg,
      appBar: const AppAppBar(title: "Verify It's You"),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DesignTokens.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: DesignTokens.spacing8),
              Text(
                "Enter the code",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: DesignTokens.text,
                      fontSize: 24,
                    ),
              ),
              const SizedBox(height: DesignTokens.spacing8),
              Text(
                widget.maskedEmail != null
                    ? "We sent a 6-digit code to ${widget.maskedEmail}."
                    : "We sent a 6-digit code to your email.",
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: DesignTokens.muted),
              ),
              const SizedBox(height: DesignTokens.spacing24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 42,
                    height: 54,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        color: DesignTokens.text,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: DesignTokens.fontDmSans,
                      ),
                      decoration: InputDecoration(
                        counterText: "",
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                        filled: true,
                        fillColor: DesignTokens.bg2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: DesignTokens.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: DesignTokens.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: DesignTokens.accent),
                        ),
                      ),
                      onChanged: (value) {
                        final sanitized = value.replaceAll(RegExp(r'\D'), '');
                        if (sanitized.isEmpty) {
                          if (value.isEmpty && index > 0) {
                            _otpFocusNodes[index - 1].requestFocus();
                          }
                          return;
                        }

                        if (value.length > 1) {
                          final pasted = value.replaceAll(RegExp(r'\D'), '');
                          final chars = pasted.split('');
                          for (var i = 0; i < 6; i++) {
                            final controller = _otpControllers[i];
                            controller.text = i < chars.length ? chars[i] : '';
                          }
                          final lastIndex =
                              chars.length >= 6 ? 5 : chars.length - 1;
                          if (lastIndex >= 0) {
                            _otpFocusNodes[lastIndex].requestFocus();
                          }
                          return;
                        }

                        _otpControllers[index].text = sanitized;
                        if (sanitized.isNotEmpty && index < 5) {
                          _otpFocusNodes[index + 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),
              if (_error != null)
                AppNotice(color: DesignTokens.red, message: _error!),
              const SizedBox(height: DesignTokens.spacing20),
              AppButton(
                label: "Confirm",
                style: AppButtonStyle.success,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
