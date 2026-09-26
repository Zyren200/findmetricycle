import "package:flutter/material.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "change_password_otp_page.dart";

/// Step 1 of the password-change flow, shared by both Passenger and
/// Driver settings (same underlying account either way). Parameterized by
/// the request/confirm calls so this UI isn't duplicated per role — only
/// the repository call underneath differs.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({
    required this.requestOtp,
    required this.confirmChange,
    super.key,
  });

  final Future<Map<String, dynamic>> Function(String currentPassword) requestOtp;
  final Future<bool> Function(
    String currentPassword,
    String newPassword,
    String otp,
  ) confirmChange;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final currentPassword = _currentCtrl.text;
    final newPassword = _newCtrl.text;

    try {
      final result = await widget.requestOtp(currentPassword);
      if (!mounted) return;

      if (result["success"] != true) {
        setState(() => _error =
            result["message"]?.toString() ?? "Failed to send verification code.");
        return;
      }

      final maskedEmail = result["email"]?.toString();
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ChangePasswordOtpPage(
            maskedEmail: maskedEmail,
            confirm: (otp) =>
                widget.confirmChange(currentPassword, newPassword, otp),
          ),
        ),
      );

      if (saved == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.bg,
      appBar: const AppAppBar(title: "Change Password"),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DesignTokens.spacing16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: DesignTokens.spacing8),
                Text(
                  "Update your password",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: DesignTokens.text,
                        fontSize: 24,
                      ),
                ),
                const SizedBox(height: DesignTokens.spacing8),
                Text(
                  "We'll email you a verification code before the change takes effect.",
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: DesignTokens.muted),
                ),
                const SizedBox(height: DesignTokens.spacing20),
                AppTextField(
                  label: "Current Password",
                  placeholder: "Enter current password",
                  controller: _currentCtrl,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Current password is required.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: DesignTokens.spacing12),
                AppTextField(
                  label: "New Password",
                  placeholder: "At least 8 characters",
                  controller: _newCtrl,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return "New password must be at least 8 characters.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: DesignTokens.spacing12),
                AppTextField(
                  label: "Confirm New Password",
                  placeholder: "Re-enter new password",
                  controller: _confirmCtrl,
                  obscureText: true,
                  validator: (value) {
                    if (value != _newCtrl.text) {
                      return "Passwords do not match.";
                    }
                    return null;
                  },
                ),
                if (_error != null)
                  AppNotice(color: DesignTokens.red, message: _error!),
                const SizedBox(height: DesignTokens.spacing20),
                AppButton(
                  label: "Continue",
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _continue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
