import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/network/api_client.dart";
import "../../../core/theme/design_tokens.dart";
import "../repositories/auth_repository.dart";

/// Step 3 of registration: fill in personal details to finish creating
/// the account for the already-verified [email].
class RegisterDetailsPage extends StatefulWidget {
  const RegisterDetailsPage({required this.email, super.key});

  final String email;

  @override
  State<RegisterDetailsPage> createState() => _RegisterDetailsPageState();
}

class _RegisterDetailsPageState extends State<RegisterDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final repo = AuthRepository(context.read<ApiClient>());
      final response = await repo.registerPassengerV2(
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text,
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: widget.email,
        password: _passwordController.text.trim(),
      );

      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Registration failed.");
      }

      if (!mounted) return;
      await _showSuccessAndReturnToLogin();
    } catch (e) {
      setState(() => _error = _formatError(e));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showSuccessAndReturnToLogin() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: DesignTokens.bg2,
        title: Text(
          "Account created",
          style: TextStyle(color: DesignTokens.text),
        ),
        content: Text(
          "Your account was created successfully. You can now log in.",
          style: TextStyle(color: DesignTokens.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              "OK",
              style: TextStyle(color: DesignTokens.accent),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
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
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: DesignTokens.spacing8),
                Text(
                  "Tell us about yourself",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: DesignTokens.text,
                        fontSize: 26,
                      ),
                ),
                const SizedBox(height: DesignTokens.spacing8),
                Text(
                  "Registering as ${widget.email}",
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: DesignTokens.muted),
                ),
                const SizedBox(height: DesignTokens.spacing20),
                AppTextField(
                  label: "First Name",
                  placeholder: "Juan",
                  controller: _firstNameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "First name is required.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: DesignTokens.spacing12),
                AppTextField(
                  label: "Middle Name (optional)",
                  placeholder: "Optional",
                  controller: _middleNameController,
                ),
                const SizedBox(height: DesignTokens.spacing12),
                AppTextField(
                  label: "Last Name",
                  placeholder: "Dela Cruz",
                  controller: _lastNameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Last name is required.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: DesignTokens.spacing12),
                AppTextField(
                  label: "Phone",
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  placeholder: "+639123456789",
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Phone number is required.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: DesignTokens.spacing12),
                AppTextField(
                  label: "Password",
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  placeholder: "At least 8 characters",
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: DesignTokens.muted,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 8) {
                      return "Password must be at least 8 characters.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: DesignTokens.spacing20),
                AppButton(
                  label: "Create Account",
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _register,
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
