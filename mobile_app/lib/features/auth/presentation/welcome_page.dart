import "package:flutter/gestures.dart";
import "package:flutter/material.dart";

import "../../../core/components/prism.dart";
import "../../../core/components/sunrise.dart";
import "../../../core/theme/design_tokens.dart";

/// Welcome: the prism halo, "Sakay na, Guiuan.", and "Create an account"
/// / "Log in".
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.onSignup, required this.onLogin});

  final VoidCallback onSignup;
  final VoidCallback onLogin;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late final _terms = TapGestureRecognizer()
    ..onTap = () => _info("Terms of Service",
        "Our full Terms of Service will be published here soon. For questions in the meantime, contact FindMeTricycle support.");
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => _info("Privacy Policy",
        "We use your location only while you book or ride, and share your name with your rider. Our full Privacy Policy will be published here soon.");

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  void _info(String title, String message) {
    showSunSheet<void>(
      context,
      builder: (dialogContext) => SunSheetCard(
        title: title,
        message: message,
        align: CrossAxisAlignment.start,
        actions: [
          SunButton(
            label: "Close",
            tone: SunTone.quiet,
            height: 48,
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final link = TextStyle(
      color: DesignTokens.lagoonText,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: DesignTokens.lagoonText.withValues(alpha: .45),
    );
    final hero = TextStyle(
      color: DesignTokens.ink,
      fontSize: 46,
      height: 0.98,
      fontWeight: FontWeight.w800,
      letterSpacing: -2.5,
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // The prism halo turning behind the upper third (".halo-ring").
          const Align(alignment: Alignment(0, -0.42), child: PrismHalo()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: Stagger.wrap([
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: PrismMark(size: 52),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Sakay na,", style: hero),
                            const GlowText("Guiuan.", fontSize: 46),
                          ],
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Text(
                              "Book a tricycle, know your rider, and ride safely around Guiuan.",
                              style: TextStyle(
                                  color: DesignTokens.ink2,
                                  fontSize: 15,
                                  height: 1.55)),
                        ),
                        Column(
                          children: [
                            SunButton(
                                label: "Create an account",
                                onPressed: widget.onSignup),
                            const SizedBox(height: 10),
                            SunButton(
                                label: "Log in",
                                tone: SunTone.quiet,
                                onPressed: widget.onLogin),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              "Want to drive? Apply on the website with the same account.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: DesignTokens.ink2,
                                  fontSize: 12,
                                  height: 1.5),
                            ),
                            const SizedBox(height: 6),
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                    color: DesignTokens.ink2,
                                    fontSize: 12,
                                    height: 1.5),
                                children: [
                                  const TextSpan(
                                      text: "By continuing, you agree to our "),
                                  TextSpan(
                                      text: "Terms of Service",
                                      style: link,
                                      recognizer: _terms),
                                  const TextSpan(text: " and "),
                                  TextSpan(
                                      text: "Privacy Policy",
                                      style: link,
                                      recognizer: _privacy),
                                  const TextSpan(text: "."),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ], gap: 22),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
