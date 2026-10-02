import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/components/index.dart";
import "../../../core/network/api_client.dart";
import "../../../core/theme/design_tokens.dart";
import "../repositories/auth_repository.dart";
import "register_details_page.dart";

/// Step 2 of registration: enter the OTP that was sent to [email].
class RegisterOtpPage extends StatefulWidget {
  const RegisterOtpPage({required this.email, super.key});

  final String email;

  @override
  State<RegisterOtpPage> createState() => _RegisterOtpPageState();
}

class _RegisterOtpPageState extends State<RegisterOtpPage> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (_) => FocusNode(),
  );

  bool _isSubmitting = false;
  bool _isResending = false;
  String? _error;
  String? _success;
  int _countdown = 60;
  Timer? _timer;

  String get _otpCode =>
      _otpControllers.map((controller) => controller.text).join();

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
        return;
      }
      setState(() => _countdown--);
    });
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isResending = true;
      _error = null;
      _success = null;
    });

    try {
      final repo = AuthRepository(context.read<ApiClient>());
      final response = await repo.sendOtp(email: widget.email);
      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Could not resend OTP.");
      }

      for (final controller in _otpControllers) {
        controller.clear();
      }
      setState(() => _success = "OTP sent to ${widget.email}.");
      _startCountdown();
    } catch (e) {
      setState(() => _error = _formatError(e));
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCode;
    if (code.length != 6) {
      setState(() => _error = "Enter the 6-digit OTP sent to your email.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
      _success = null;
    });

    try {
      final repo = AuthRepository(context.read<ApiClient>());
      final response = await repo.verifyOtp(email: widget.email, code: code);
      if (response["success"] != true && response["verified"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "OTP verification failed.");
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterDetailsPage(email: widget.email),
        ),
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
      final message = error.toString().replaceFirst("Exception: ", "");
      if (message.contains("Invalid or expired OTP")) {
        return "The OTP is invalid or expired. Please request a new code.";
      }
      return message;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: DesignTokens.spacing8),
              Text(
                "Enter the code",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: DesignTokens.text,
                      fontSize: 26,
                    ),
              ),
              const SizedBox(height: DesignTokens.spacing8),
              Text(
                "We sent a 6-digit code to ${widget.email}.",
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
                      inputFormatters: const [],
                      style: TextStyle(
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
                          borderSide: BorderSide(color: DesignTokens.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: DesignTokens.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: DesignTokens.accent),
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
              const SizedBox(height: DesignTokens.spacing20),
              AppButton(
                label: "Verify OTP",
                style: AppButtonStyle.success,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _verifyOtp,
              ),
              const SizedBox(height: DesignTokens.spacing16),
              Center(
                child: _countdown > 0
                    ? Text(
                        "Resend code in $_countdown s",
                        style: TextStyle(color: DesignTokens.muted),
                      )
                    : TextButton(
                        onPressed: _isResending ? null : _resendOtp,
                        child: Text(
                          _isResending ? "Resending…" : "Resend OTP",
                          style: TextStyle(color: DesignTokens.accent),
                        ),
                      ),
              ),
              if (_error != null)
                AppNotice(color: DesignTokens.red, message: _error!),
              if (_success != null)
                AppNotice(color: DesignTokens.green, message: _success!),
            ],
          ),
        ),
      ),
    );
  }
}
