import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:provider/provider.dart";
import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../../shared/state/session_store.dart";
import "forgot_password_page.dart";

/// "Welcome back": email or mobile number and password. Errors land on
/// the field they're about ("This email is not registered." under the
/// first field) and what was typed stays put.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onBack, this.onSignup});

  /// Back to the welcome screen (hidden when null).
  final VoidCallback? onBack;
  final VoidCallback? onSignup;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _identifierError;
  String? _passwordError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  static final _emailPattern = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
  // Same shape the backend's phoneSchema accepts.
  static final _phonePattern = RegExp(r"^[0-9+ -]{7,20}$");

  String? _validateIdentifier(String value) {
    final input = value.trim();
    if (input.isEmpty) return "Enter your email or mobile number.";
    if (input.contains("@")) {
      return _emailPattern.hasMatch(input)
          ? null
          : "Enter a valid email address.";
    }
    return _phonePattern.hasMatch(input)
        ? null
        : "Enter a valid email or mobile number.";
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final idError = _validateIdentifier(_identifierController.text);
    final pwError =
        _passwordController.text.trim().isEmpty ? "Enter your password." : null;
    setState(() {
      _identifierError = idError;
      _passwordError = pwError;
    });
    if (idError != null || pwError != null) return;

    final sessionStore = context.read<SessionStore>();
    final storage = context.read<FlutterSecureStorage>();

    await sessionStore.login(
      storage: storage,
      emailOrPhone: _identifierController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  Future<void> _openForgotPassword() async {
    final identifier = _identifierController.text.trim();
    // The reset's email, once the new password is saved.
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(
          initialEmail: identifier.contains("@") ? identifier : null,
        ),
      ),
    );
    if (email == null || !mounted) return;

    // Ready to log in with the new password: the email is filled in, and
    // the old (wrong) password and its errors no longer apply.
    _identifierController.text = email;
    _passwordController.clear();
    setState(() {
      _identifierError = null;
      _passwordError = null;
    });
    context.read<SessionStore>().clearError();
    showSunToast(context, "Password updated. Log in with your new password.");
  }

  @override
  Widget build(BuildContext context) {
    final sessionStore = context.watch<SessionStore>();
    final errorField = sessionStore.errorField;
    final serverIdentifierError =
        (errorField == "email" || errorField == "phone")
            ? sessionStore.error
            : null;
    final serverPasswordError =
        errorField == "password" ? sessionStore.error : null;
    final generalError =
        (serverIdentifierError == null && serverPasswordError == null)
            ? sessionStore.error
            : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.onBack != null)
                  Row(children: [
                    BackSquareButton(onTap: widget.onBack),
                  ]),
                const SizedBox(height: 22),
                FadeRise(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Welcome back",
                          style: DesignTokens.display),
                      const SizedBox(height: 6),
                      Text("Log in to book a tricycle in Guiuan.",
                          style: TextStyle(
                              color: DesignTokens.ink2,
                              fontSize: 15,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SunField(
                  label: "Email or mobile number",
                  controller: _identifierController,
                  icon: Icons.person_outline_rounded,
                  hint: "juan@example.com or 0917 123 4567",
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email
                  ],
                  errorText: _identifierError ?? serverIdentifierError,
                  // What the user typed stays put; editing it just
                  // clears the "not registered" message.
                  onChanged: (_) {
                    if (_identifierError != null) {
                      setState(() => _identifierError = null);
                    }
                    if (serverIdentifierError != null) {
                      sessionStore.clearError();
                    }
                  },
                ),
                const SizedBox(height: 16),
                SunField(
                  label: "Password",
                  controller: _passwordController,
                  icon: Icons.lock_outline_rounded,
                  hint: "Enter your password",
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  labelTrailing: GestureDetector(
                    onTap: sessionStore.isLoading ? null : _openForgotPassword,
                    child: Text("Forgot password?",
                        style: TextStyle(
                            color: DesignTokens.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                  errorText: _passwordError ?? serverPasswordError,
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                    if (serverPasswordError != null) {
                      sessionStore.clearError();
                    }
                  },
                ),
                if (generalError != null) ...[
                  const SizedBox(height: 14),
                  ErrorBox(message: generalError),
                ],
                const SizedBox(height: 22),
                SunButton(
                  label: "Log in",
                  loading: sessionStore.isLoading,
                  onPressed: sessionStore.isLoading ? null : _submit,
                ),
                const SizedBox(height: 40),
                if (widget.onSignup != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("New to FindMeTricycle?",
                          style: TextStyle(
                              color: DesignTokens.ink2,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      SunLink(
                        label: "Create an account",
                        onTap: sessionStore.isLoading ? null : widget.onSignup,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
