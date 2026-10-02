import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/network/api_client.dart";
import "../../../core/theme/design_tokens.dart";
import "../../shared/presentation/change_password_otp_page.dart";
import "../repositories/auth_repository.dart";

/// Step 1 of the logged-out password reset — the same two steps as the
/// in-app Change Password flow, with the account's email standing in for
/// the current password. Step 2 reuses [ChangePasswordOtpPage]. Pops true
/// once the new password is saved.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({this.initialEmail, super.key});

  /// Pre-filled from the login form when the user had typed an email there.
  final String? initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static final _emailPattern = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");

  final _formKey = GlobalKey<FormState>();
  late final _emailCtrl = TextEditingController(text: widget.initialEmail);
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _emailError;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _emailError = null;
      _error = null;
    });

    final repo = AuthRepository(context.read<ApiClient>());
    final email = _emailCtrl.text.trim();
    final newPassword = _newCtrl.text;

    try {
      final result = await repo.requestPasswordReset(email: email);
      if (!mounted) return;

      if (result["success"] != true) {
        final message = result["message"]?.toString() ??
            "Failed to send verification code.";
        final details = result["details"];
        setState(() {
          if (details is Map && details["field"] == "email") {
            _emailError = message;
          } else {
            _error = message;
          }
        });
        return;
      }

      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ChangePasswordOtpPage(
            maskedEmail: email,
            confirm: (otp) async {
              try {
                final response = await repo.resetPassword(
                  email: email,
                  code: otp,
                  newPassword: newPassword,
                );
                return response["success"] == true;
              } catch (_) {
                return false;
              }
            },
          ),
        ),
      );

      if (saved == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Request failed. Please try again.");
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
      appBar: const AppAppBar(title: "Forgot Password"),
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
                  "Reset your password",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: DesignTokens.text,
                        fontSize: 24,
                      ),
                ),
                const SizedBox(height: DesignTokens.spacing8),
                Text(
                  "Enter the email on your account. We'll email you a verification code before the new password takes effect.",
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: DesignTokens.muted),
                ),
                const SizedBox(height: DesignTokens.spacing20),
                AppTextField(
                  label: "Email",
                  placeholder: "name@example.com",
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                  onChanged: (_) {
                    if (_emailError != null) {
                      setState(() => _emailError = null);
                    }
                  },
                  validator: (value) {
                    final input = value?.trim() ?? "";
                    if (input.isEmpty) return "Email is required.";
                    if (!_emailPattern.hasMatch(input)) {
                      return "Enter a valid email address.";
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
