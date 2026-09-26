import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:provider/provider.dart";
import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../../shared/state/session_store.dart";
import "register_email_page.dart";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final sessionStore = context.read<SessionStore>();
    final storage = context.read<FlutterSecureStorage>();

    await sessionStore.login(
      storage: storage,
      emailOrPhone: _identifierController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionStore = context.watch<SessionStore>();

    return Scaffold(
      body: Container(
        color: DesignTokens.bg,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: DesignTokens.spacing12),
                Center(
                  child: Column(
                    children: [
                      const Text(
                        "🛺",
                        style: TextStyle(fontSize: 56),
                      ),
                      const SizedBox(height: DesignTokens.spacing12),
                      Text(
                        "FindMeTricycle",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: DesignTokens.accent,
                              fontSize: 30,
                            ),
                      ),
                      const SizedBox(height: DesignTokens.spacing6),
                      Text(
                        "Welcome back",
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(letterSpacing: 1.1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: "Email or Mobile Number",
                        placeholder: "name@example.com or +63 9XX XXX XXXX",
                        controller: _identifierController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? "Email or mobile number is required"
                                : null,
                      ),
                      const SizedBox(height: DesignTokens.spacing14),
                      AppTextField(
                        label: "Password",
                        placeholder: "Enter password",
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: DesignTokens.muted,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? "Password is required"
                                : null,
                      ),
                      const SizedBox(height: DesignTokens.spacing14),
                      if (sessionStore.error != null)
                        Container(
                          padding: const EdgeInsets.all(DesignTokens.spacing12),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(31, 240, 92, 92),
                            borderRadius:
                                BorderRadius.circular(DesignTokens.radius),
                            border: Border.all(
                              color: const Color.fromARGB(51, 240, 92, 92),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            sessionStore.error!,
                            style: const TextStyle(
                              color: DesignTokens.red,
                              fontSize: DesignTokens.fontSize12,
                              fontFamily: DesignTokens.fontDmSans,
                            ),
                          ),
                        ),
                      const SizedBox(height: DesignTokens.spacing14),
                      AppButton(
                        label: "Login",
                        isLoading: sessionStore.isLoading,
                        onPressed: sessionStore.isLoading ? null : _submit,
                      ),
                      const SizedBox(height: DesignTokens.spacing10),
                      AppButton(
                        label: "Create Account",
                        style: AppButtonStyle.ghost,
                        onPressed: sessionStore.isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterEmailPage(),
                                  ),
                                );
                              },
                      ),
                      const SizedBox(height: DesignTokens.spacing12),
                      Text(
                        "Forgot password? Reset",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: DesignTokens.muted,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


