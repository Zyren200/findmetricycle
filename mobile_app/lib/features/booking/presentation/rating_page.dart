import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../repositories/booking_repository.dart";

class RatingPage extends StatefulWidget {
  const RatingPage({
    super.key,
    required this.bookingId,
    this.driverName,
    this.vehicle,
  });

  final int bookingId;
  final String? driverName;
  final String? vehicle;

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  final TextEditingController _feedbackController = TextEditingController();
  int _stars = 5;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final repo = context.read<BookingRepository>();
      final response = await repo.rate(
        bookingId: widget.bookingId,
        stars: _stars,
        feedback: _feedbackController.text.trim(),
      );

      if (response["success"] != true) {
        throw Exception(
            response["message"]?.toString() ?? "Failed to submit rating.");
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  static const _words = ["Poor", "Fair", "Okay", "Good", "Excellent"];

  @override
  Widget build(BuildContext context) {
    final driverName = widget.driverName?.trim();
    final hasName = driverName != null && driverName.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          const AppTopBar(title: "Rate your rider", showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
              children: [
                if (hasName) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: DesignTokens.lagoon.withValues(alpha: .7),
                            width: 1.5),
                      ),
                      child: ToneAvatar(
                          name: driverName, size: 72, circle: true),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(driverName,
                      textAlign: TextAlign.center, style: DesignTokens.title),
                  if (widget.vehicle != null) ...[
                    const SizedBox(height: 4),
                    Text(widget.vehicle!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: DesignTokens.ink2, fontSize: 13.5)),
                  ],
                  const SizedBox(height: 24),
                ],
                Text("How was your ride?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: DesignTokens.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                RateStars(
                  value: _stars,
                  onChanged: (v) => setState(() => _stars = v),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: DesignTokens.quick,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: DesignTokens.font,
                    color: _stars > 0 ? DesignTokens.amberInk : DesignTokens.ink2,
                    fontSize: 13,
                    fontWeight: _stars > 0 ? FontWeight.w600 : FontWeight.w400,
                  ),
                  child: Text(_stars == 0
                      ? "Tap a star to rate"
                      : "$_stars star${_stars > 1 ? "s" : ""} · ${_words[_stars - 1]}"),
                ),
                const SizedBox(height: 20),
                SunField(
                  label: "Comment (optional)",
                  controller: _feedbackController,
                  hint: "Add a comment",
                  maxLines: 3,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBox(message: _error!),
                ],
                const SizedBox(height: 22),
                SunButton(
                  label: "Submit rating",
                  loading: _isSubmitting,
                  onPressed: _stars == 0 || _isSubmitting ? null : _submit,
                ),
                const SizedBox(height: 6),
                SunButton(
                  label: "Skip",
                  tone: SunTone.ghost,
                  height: 44,
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
