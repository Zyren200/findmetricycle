import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/network/api_client.dart";
import "../../../core/theme/design_tokens.dart";
import "../../shared/state/session_store.dart";
import "../repositories/auth_repository.dart";

enum _Step { email, code, details }

/// Create an account in three steps under one progress bar: email → the
/// 6-digit code sent there → name, mobile number and password. The new
/// account is signed in right away.
class SignupPage extends StatefulWidget {
  const SignupPage({super.key, required this.onBack, required this.onLogin});

  /// Leaves sign-up (back from the first step).
  final VoidCallback onBack;
  final VoidCallback onLogin;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  _Step _step = _Step.email;

  final _email = TextEditingController();
  final _code = TextEditingController();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _emailError;
  bool _detailsTried = false;
  int _countdown = 0;
  Timer? _timer;

  static final _emailPattern = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [
      _email,
      _code,
      _firstName,
      _middleName,
      _lastName,
      _mobile,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  AuthRepository get _repo => AuthRepository(context.read<ApiClient>());

  String _message(Object error) =>
      error.toString().replaceFirst("Exception: ", "");

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
        widget.onBack();
      case _Step.code:
        setState(() => _step = _Step.email);
      case _Step.details:
        setState(() => _step = _Step.code);
    }
  }

  // ── Step 1 ────────────────────────────────────────────────────────────

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _emailError = "Enter a valid email address.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _emailError = null;
    });
    try {
      final response = await _repo.sendOtp(email: email);
      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Could not send the code.");
      }
      if (!mounted) return;
      _code.clear();
      _startCountdown();
      setState(() => _step = _Step.code);
    } catch (e) {
      if (mounted) setState(() => _emailError = _message(e));
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
      final response = await _repo.sendOtp(email: _email.text.trim());
      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Could not resend the code.");
      }
      if (!mounted) return;
      _code.clear();
      _startCountdown();
      showSunToast(context, "New code sent to ${_email.text.trim()}.");
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text;
    if (code.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response =
          await _repo.verifyOtp(email: _email.text.trim(), code: code);
      if (response["success"] != true && response["verified"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Verification failed.");
      }
      if (mounted) setState(() => _step = _Step.details);
    } catch (e) {
      final message = _message(e);
      if (mounted) {
        setState(() => _error = message.contains("Invalid or expired OTP")
            ? "The code is invalid or expired. Request a new one."
            : message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Step 3 ────────────────────────────────────────────────────────────

  /// "917 123 4567" or "0917…" → "09171234567", the format people log in
  /// with.
  String get _phone {
    var digits = _mobile.text.replaceAll(RegExp(r"\D"), "");
    if (digits.startsWith("63") && digits.length > 10) {
      digits = digits.substring(2);
    }
    if (digits.startsWith("0")) digits = digits.substring(1);
    return "0$digits";
  }

  bool get _phoneOk => RegExp(r"^09\d{9}$").hasMatch(_phone);

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    setState(() => _detailsTried = true);
    if (_firstName.text.trim().isEmpty ||
        _lastName.text.trim().isEmpty ||
        !_phoneOk ||
        _password.text.trim().length < 8) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final email = _email.text.trim();
    final password = _password.text.trim();
    try {
      final response = await _repo.registerPassengerV2(
        firstName: _firstName.text.trim(),
        middleName: _middleName.text,
        lastName: _lastName.text.trim(),
        phone: _phone,
        email: email,
        password: password,
      );
      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Registration failed.");
      }
      if (!mounted) return;

      // Signed in right away; the router takes it from here.
      final sessionStore = context.read<SessionStore>();
      final ok = await sessionStore.login(
        storage: context.read<FlutterSecureStorage>(),
        emailOrPhone: email,
        password: password,
      );
      if (!ok && mounted) {
        await showSunSheet<void>(
          context,
          builder: (dialogContext) => SunSheetCard(
            title: "Account created",
            message: "Your account is ready. Log in to start booking.",
            icon: Icons.check_rounded,
            iconBg: DesignTokens.lagoonSoft,
            iconFg: DesignTokens.lagoonText,
            actions: [
              SunButton(
                label: "Log in",
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        );
        if (mounted) widget.onLogin();
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
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
        if (!didPop) _back();
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
                        label: "Sign-up progress",
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
                      _Step.details => _detailsStep(),
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
          Text(title,
              style: DesignTokens.display),
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

  Widget _emailStep() {
    return _scroll([
      _heading("What's your email?",
          const Text("We'll send a 6-digit code to confirm it's you.")),
      const SizedBox(height: 22),
      SunField(
        label: "Email address",
        controller: _email,
        icon: Icons.mail_outline_rounded,
        hint: "juan@example.com",
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.send,
        autofocus: true,
        errorText: _emailError,
        onSubmitted: (_) => _sendCode(),
        onChanged: (_) {
          if (_emailError != null) setState(() => _emailError = null);
        },
      ),
      const SizedBox(height: 16),
      SunButton(label: "Send code", loading: _busy, onPressed: _sendCode),
      const SizedBox(height: 40),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Already have an account?",
              style: TextStyle(
                  color: DesignTokens.ink2,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          SunLink(label: "Log in", onTap: _busy ? null : widget.onLogin),
        ],
      ),
    ]);
  }

  Widget _codeStep() {
    return _scroll([
      _heading(
        "Enter the code",
        Text.rich(TextSpan(children: [
          const TextSpan(text: "We sent a 6-digit code to "),
          TextSpan(
              text: _email.text.trim(),
              style: TextStyle(
                  color: DesignTokens.ink, fontWeight: FontWeight.w700)),
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
      if (_error != null) ...[
        const SizedBox(height: 12),
        ErrorBox(message: _error!),
      ],
      const SizedBox(height: 22),
      SunButton(
        label: "Verify",
        loading: _busy,
        onPressed: _code.text.length == 6 ? _verify : null,
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
            onTap: _countdown > 0 || _resending ? null : _resend,
          ),
        ],
      ),
    ]);
  }

  Widget _detailsStep() {
    final pw = _password.text;
    final pwHint = pw.length >= 8
        ? "Strong enough"
        : pw.isNotEmpty
            ? "${8 - pw.length} more characters"
            : "Use at least 8 characters";
    String? need(TextEditingController c, String message) =>
        _detailsTried && c.text.trim().isEmpty ? message : null;

    return _scroll([
      _heading(
          "Almost done", const Text("Riders see your name when you book.")),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SunField(
              label: "First name",
              controller: _firstName,
              hint: "Juan",
              autofillHints: const [AutofillHints.givenName],
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              errorText: need(_firstName, "Required"),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SunField(
              label: "Last name",
              controller: _lastName,
              hint: "Dela Cruz",
              autofillHints: const [AutofillHints.familyName],
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              errorText: need(_lastName, "Required"),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      SunField(
        label: "Middle name (optional)",
        controller: _middleName,
        hint: "Optional",
        autofillHints: const [AutofillHints.middleName],
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      SunField(
        label: "Mobile number",
        controller: _mobile,
        hint: "917 123 4567",
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumberNational],
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r"[\d ]")),
          LengthLimitingTextInputFormatter(13),
        ],
        prefix: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: DesignTokens.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text("+63",
              style: TextStyle(
                  color: DesignTokens.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: DesignTokens.tabular)),
        ),
        errorText: _detailsTried && !_phoneOk
            ? "Enter a valid mobile number (e.g. 917 123 4567)."
            : null,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 14),
      SunField(
        label: "Password",
        controller: _password,
        hint: "At least 8 characters",
        obscure: true,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _create(),
        errorText: _detailsTried && pw.trim().length < 8
            ? "Passwords need at least 8 characters."
            : null,
        helper: pwHint,
        helperColor: pw.length >= 8 ? DesignTokens.lagoonText : null,
        onChanged: (_) => setState(() {}),
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        ErrorBox(message: _error!),
      ],
      const SizedBox(height: 18),
      SunButton(label: "Create account", loading: _busy, onPressed: _create),
    ]);
  }
}
