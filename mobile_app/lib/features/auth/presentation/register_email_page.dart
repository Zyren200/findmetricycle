import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/network/api_client.dart";
import "../../../core/theme/design_tokens.dart";
import "../repositories/auth_repository.dart";
import "register_otp_page.dart";

/// Step 1 of registration: collect the user's email and send them an OTP.
class RegisterEmailPage extends StatefulWidget {
  const RegisterEmailPage({super.key});

  @override
  State<RegisterEmailPage> createState() => _RegisterEmailPageState();
}

class _RegisterEmailPageState extends State<RegisterEmailPage> {
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r"^[^@]+@[^@]+\.[^@]+$").hasMatch(email)) {
      setState(() => _error = "Enter a valid email address.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final repo = AuthRepository(context.read<ApiClient>());
      final response = await repo.sendOtp(email: email);
      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Could not send OTP.");
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RegisterOtpPage(email: email)),
      );
    } catch (e) {
      setState(() => _error = _formatError(e));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatError(Object error) {
    if (error is Exception) {
      return error.toString().replaceFirst("Exception: ", "");
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.bg,
      appBar: const AppAppBar(title: "Create Account"),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DesignTokens.spacing16),
          child: Form(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: DesignTokens.spacing8),
                Text(
                  "Verify your email to continue",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: DesignTokens.text,
                        fontSize: 26,
                      ),
                ),
                const SizedBox(height: DesignTokens.spacing8),
                Text(
                  "We'll send a 6-digit code to this email to confirm it's yours.",
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: DesignTokens.muted),
                ),
                const SizedBox(height: DesignTokens.spacing20),
                AppTextField(
                  label: "Email",
                  placeholder: "name@example.com",
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: DesignTokens.spacing20),
                AppButton(
                  label: "Verify Email",
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _verifyEmail,
                ),
                if (_error != null)
                  AppNotice(color: DesignTokens.red, message: _error!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
