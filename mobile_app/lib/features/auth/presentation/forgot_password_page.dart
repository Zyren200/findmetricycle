import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/network/api_client.dart";
import "../../../core/theme/design_tokens.dart";
import "../repositories/auth_repository.dart";

enum _Step { email, code, password }

/// The login page's "Forgot password?", in three steps under one progress
/// bar: the account's email → the 6-digit code sent there, checked before
/// going on → the new password. Pops the email once the new password is
/// saved, so the login form can be filled in with it.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({this.initialEmail, super.key});

  /// Pre-filled from the login form when the user had typed an email there.
  final String? initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  _Step _step = _Step.email;

  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _resending = false;
  bool _passwordTried = false;
  String? _emailError;
  String? _error;
  int _countdown = 0;
  Timer? _timer;

  static final _emailPattern = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
  // What the backend says for a wrong, expired or used-up code.
  static const _invalidCode = "Invalid or expired code";
  static const _offline = "Request failed. Check your connection and try again.";

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  AuthRepository get _repo => AuthRepository(context.read<ApiClient>());

  String get _emailValue => _email.text.trim();

  // Trimmed, the same way the login form sends it.
  String get _newPassword => _password.text.trim();

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _back() {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    switch (_step) {
      case _Step.email:
        Navigator.of(context).pop();
      case _Step.code:
        setState(() => _step = _Step.email);
      case _Step.password:
        // A verified code can't be checked again, so going back starts
        // over with a fresh one.
        setState(() => _step = _Step.email);
    }
  }

  // ── Step 1 ────────────────────────────────────────────────────────────

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    final email = _emailValue;
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _emailError = email.isEmpty
          ? "Enter your email address."
          : "Enter a valid email address.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _emailError = null;
    });
    try {
      final response = await _repo.requestPasswordReset(email: email);
      if (!mounted) return;
      if (response["success"] != true) {
        final message =
            response["message"]?.toString() ?? "Could not send the code.";
        final details = response["details"];
        setState(() {
          if (details is Map && details["field"] == "email") {
            _emailError = message; // "This email is not registered."
          } else {
            _error = message;
          }
        });
        return;
      }
      _code.clear();
      _startCountdown();
      setState(() => _step = _Step.code);
    } catch (_) {
      if (mounted) setState(() => _error = _offline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Step 2 ────────────────────────────────────────────────────────────

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final response = await _repo.requestPasswordReset(email: _emailValue);
      if (!mounted) return;
      if (response["success"] != true) {
        setState(() => _error =
            response["message"]?.toString() ?? "Could not resend the code.");
        return;
      }
      _code.clear();
      _startCountdown();
      showSunToast(context, "New code sent to $_emailValue.");
    } catch (_) {
      if (mounted) setState(() => _error = _offline);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text;
    if (code.length != 6 || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response =
          await _repo.verifyPasswordResetCode(email: _emailValue, code: code);
      if (!mounted) return;
      if (response["success"] != true) {
        final message = response["message"]?.toString();
        setState(() => _error = message == _invalidCode
            ? "The code is invalid or expired. Check it, or request a new one."
            : (message ?? "Verification failed."));
        return;
      }
      _password.clear();
      _confirm.clear();
      setState(() {
        _passwordTried = false;
        _step = _Step.password;
      });
    } catch (_) {
      if (mounted) setState(() => _error = _offline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Step 3 ────────────────────────────────────────────────────────────

  bool get _passwordOk => _newPassword.length >= 8;
  bool get _confirmOk => _confirm.text.trim() == _newPassword;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _passwordTried = true);
    if (!_passwordOk || !_confirmOk) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _repo.resetPassword(
        email: _emailValue,
        code: _code.text,
        newPassword: _newPassword,
      );
      if (!mounted) return;
      if (response["success"] != true) {
        final message = response["message"]?.toString();
        if (message == _invalidCode) {
          // Too long since the code was verified: start over.
          _code.clear();
          setState(() {
            _step = _Step.email;
            _error = "Your code expired. Send a new one to continue.";
          });
          return;
        }
        setState(
            () => _error = message ?? "Could not save the new password.");
        return;
      }
      Navigator.of(context).pop(_emailValue);
    } catch (_) {
      if (mounted) setState(() => _error = _offline);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final stepNum = _step.index + 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    BackSquareButton(onTap: _busy ? null : _back),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Semantics(
                        label: "Password reset progress",
                        value: "Step $stepNum of 3",
                        child: Row(
                          children: [
                            for (var i = 1; i <= 3; i++) ...[
                              if (i > 1) const SizedBox(width: 6),
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: i <= stepNum
                                        ? DesignTokens.primaryBright
                                        : DesignTokens.lineStrong,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text("$stepNum of 3",
                        style: TextStyle(
                            color: DesignTokens.ink2,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFeatures: DesignTokens.tabular)),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: DesignTokens.easeOut,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween(begin: const Offset(0.08, 0), end: Offset.zero)
                              .animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: switch (_step) {
                      _Step.email => _emailStep(),
                      _Step.code => _codeStep(),
                      _Step.password => _passwordStep(),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, Widget subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DesignTokens.display),
          const SizedBox(height: 6),
          DefaultTextStyle.merge(
            style: TextStyle(
                color: DesignTokens.ink2,
                fontSize: 15,
                height: 22 / 15,
                fontWeight: FontWeight.w500),
            child: subtitle,
          ),
        ],
      );

  Widget _scroll(List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );

  List<Widget> _errorBox() => [
        if (_error != null) ...[
          const SizedBox(height: 14),
          ErrorBox(message: _error!),
        ],
      ];

  TextSpan _bold(String text) => TextSpan(
      text: text,
      style: TextStyle(color: DesignTokens.ink, fontWeight: FontWeight.w700));

  Widget _emailStep() {
    return _scroll([
      _heading(
          "Forgot your password?",
          const Text(
              "Enter the email on your account. We'll send a 6-digit code to confirm it's you.")),
      const SizedBox(height: 22),
      SunField(
        label: "Email address",
        controller: _email,
        icon: Icons.mail_outline_rounded,
        hint: "juan@example.com",
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.send,
        autofocus: widget.initialEmail == null,
        errorText: _emailError,
        onSubmitted: (_) => _sendCode(),
        onChanged: (_) {
          if (_emailError != null) setState(() => _emailError = null);
        },
      ),
      ..._errorBox(),
      const SizedBox(height: 16),
      SunButton(
        label: "Send code",
        loading: _busy,
        onPressed: _busy ? null : _sendCode,
      ),
    ]);
  }

  Widget _codeStep() {
    return _scroll([
      _heading(
        "Enter the code",
        Text.rich(TextSpan(children: [
          const TextSpan(text: "We sent a 6-digit code to "),
          _bold(_emailValue),
          const TextSpan(text: ". It expires in 5 minutes."),
        ])),
      ),
      const SizedBox(height: 22),
      OtpInput(
        controller: _code,
        error: _error != null,
        onChanged: (_) => setState(() => _error = null),
        onCompleted: (_) => _verify(),
      ),
      ..._errorBox(),
      const SizedBox(height: 22),
      SunButton(
        label: "Verify",
        loading: _busy,
        onPressed: _code.text.length == 6 && !_busy ? _verify : null,
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Didn't get it?",
              style: TextStyle(
                  color: DesignTokens.ink2,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          SunLink(
            label: _countdown > 0
                ? "Resend in ${_countdown}s"
                : (_resending ? "Sending…" : "Resend code"),
            onTap: _countdown > 0 || _resending || _busy ? null : _resend,
          ),
        ],
      ),
    ]);
  }

  Widget _passwordStep() {
    final pw = _newPassword;
    final missing = 8 - pw.length;
    final pwHint = pw.length >= 8
        ? "Strong enough"
        : pw.isNotEmpty
            ? "$missing more character${missing == 1 ? "" : "s"}"
            : "Use at least 8 characters";

    return _scroll([
      _heading(
        "Set a new password",
        Text.rich(TextSpan(children: [
          const TextSpan(text: "Email verified. Choose a new password for "),
          _bold(_emailValue),
          const TextSpan(
              text: ". You'll be logged out on your other devices."),
        ])),
      ),
      const SizedBox(height: 22),
      SunField(
        label: "New password",
        controller: _password,
        hint: "At least 8 characters",
        obscure: true,
        autofocus: true,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.next,
        errorText: _passwordTried && !_passwordOk
            ? "Passwords need at least 8 characters."
            : null,
        helper: pwHint,
        helperColor: _passwordOk ? DesignTokens.lagoonText : null,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 14),
      SunField(
        label: "Confirm new password",
        controller: _confirm,
        hint: "Re-enter the new password",
        obscure: true,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        errorText:
            _passwordTried && !_confirmOk ? "Passwords do not match." : null,
        onChanged: (_) => setState(() {}),
      ),
      ..._errorBox(),
      const SizedBox(height: 18),
      SunButton(
        label: "Save new password",
        loading: _busy,
        onPressed: _busy ? null : _save,
      ),
    ]);
  }
}
