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
  final _code = TextEditingController();

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text;
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
    final email = widget.maskedEmail;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                BackSquareButton(onTap: () => Navigator.of(context).maybePop()),
              ]),
              const SizedBox(height: 22),
              Text("Enter the code",
                  style: DesignTokens.display),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                      color: DesignTokens.ink2,
                      fontSize: 15,
                      height: 22 / 15,
                      fontWeight: FontWeight.w500),
                  children: [
                    const TextSpan(text: "We sent a 6-digit code to "),
                    TextSpan(
                        text: email ?? "your email",
                        style: TextStyle(
                            color: DesignTokens.ink,
                            fontWeight: FontWeight.w700)),
                    const TextSpan(
                        text:
                            ". Your new password takes effect once it's verified."),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              OtpInput(
                controller: _code,
                error: _error != null,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onCompleted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorBox(message: _error!),
              ],
              const SizedBox(height: 22),
              SunButton(
                label: "Verify",
                loading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
