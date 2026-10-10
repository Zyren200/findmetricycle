import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../core/state/app_preferences.dart";
import "../../../core/theme/design_tokens.dart";
import "../../shared/state/session_store.dart";
import "intro_page.dart";
import "login_page.dart";
import "signup_page.dart";
import "welcome_page.dart";

enum AuthScreen { intro, welcome, login, signup }

/// Signed out: the intro slides (first launch only), then Welcome, Log in
/// and Create an account — one screen at a time with a soft slide between
/// them. Signing in hands over to the router.
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  late AuthScreen _screen;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<AppPreferences>();
    _screen = prefs.onboardingSeen ? AuthScreen.welcome : AuthScreen.intro;
  }

  void _go(AuthScreen to, {bool forward = true}) {
    context.read<SessionStore>().clearError();
    setState(() {
      _forward = forward;
      _screen = to;
    });
  }

  void _finishIntro() {
    context.read<AppPreferences>().setOnboardingSeen();
    _go(AuthScreen.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (_screen) {
      AuthScreen.intro => IntroPage(onDone: _finishIntro),
      AuthScreen.welcome => WelcomePage(
          onSignup: () => _go(AuthScreen.signup),
          onLogin: () => _go(AuthScreen.login),
        ),
      AuthScreen.login => LoginPage(
          onBack: () => _go(AuthScreen.welcome, forward: false),
          onSignup: () => _go(AuthScreen.signup),
        ),
      AuthScreen.signup => SignupPage(
          onBack: () => _go(AuthScreen.welcome, forward: false),
          onLogin: () => _go(AuthScreen.login),
        ),
    };

    return PopScope(
      // Android back on Log in / Create account returns to Welcome.
      canPop: _screen == AuthScreen.welcome || _screen == AuthScreen.intro,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _screen == AuthScreen.login) {
          _go(AuthScreen.welcome, forward: false);
        }
      },
      child: ColoredBox(
        color: Colors.transparent,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: DesignTokens.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(_screen);
            final dx = (incoming == _forward) ? 0.12 : -0.12;
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: Offset(dx, 0), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(key: ValueKey(_screen), child: child),
        ),
      ),
    );
  }
}
