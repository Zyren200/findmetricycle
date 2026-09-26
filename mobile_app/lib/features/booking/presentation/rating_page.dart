import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";
import "../repositories/booking_repository.dart";

class RatingPage extends StatefulWidget {
  const RatingPage({
    super.key,
    required this.bookingId,
  });

  final int bookingId;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: "Rate Your Ride"),
      body: Container(
        color: DesignTokens.bg,
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "How was your ride?",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: DesignTokens.spacing16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: DesignTokens.spacing12,
                children: List.generate(
                  5,
                  (index) => GestureDetector(
                    onTap: () => setState(() => _stars = index + 1),
                    child: Container(
                      decoration: BoxDecoration(
                        color: index < _stars
                            ? DesignTokens.accent
                            : DesignTokens.bg3,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: index < _stars
                              ? DesignTokens.accent
                              : DesignTokens.border,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(DesignTokens.spacing12),
                      child: Icon(
                        Icons.star_rounded,
                        size: 32,
                        color: index < _stars
                            ? DesignTokens.bg
                            : DesignTokens.accent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spacing16),
              AppTextField(
                label: "Feedback (optional)",
                placeholder: "Tell us about your experience...",
                controller: _feedbackController,
                maxLines: 4,
              ),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spacing12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(31, 240, 92, 92),
                    borderRadius: BorderRadius.circular(DesignTokens.radius),
                    border: Border.all(
                      color: const Color.fromARGB(51, 240, 92, 92),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: DesignTokens.red),
                  ),
                ),
              const Spacer(),
              AppButton(
                label: "Submit Rating",
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
