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

  @override
  Widget build(BuildContext context) {
    final driverName = widget.driverName?.trim();
    return Scaffold(
      backgroundColor: DesignTokens.bg,
      body: Column(
        children: [
          const AppTopBar(title: "Rate Your Driver", showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                if (driverName != null && driverName.isNotEmpty) ...[
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: DesignTokens.bg3,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        driverName[0].toUpperCase(),
                        style: TextStyle(
                          color: DesignTokens.text,
                          fontSize: 24,
                          fontWeight: DesignTokens.fw700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    driverName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: DesignTokens.text,
                      fontWeight: DesignTokens.fw600,
                    ),
                  ),
                  if (widget.vehicle != null)
                    Text(
                      widget.vehicle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DesignTokens.muted, fontSize: 13),
                    ),
                  const SizedBox(height: 24),
                ],
                Text(
                  "How was your ride?",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DesignTokens.muted, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      iconSize: 40,
                      onPressed: () => setState(() => _stars = index + 1),
                      icon: Icon(
                        index < _stars
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color:
                            index < _stars ? Colors.amber : DesignTokens.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: "Feedback (optional)",
                  placeholder: "Optional feedback...",
                  controller: _feedbackController,
                  maxLines: 3,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBox(message: _error!),
                ],
                const SizedBox(height: 24),
                PrimaryActionButton(
                  label: _isSubmitting ? "Submitting..." : "Submit Rating",
                  loading: _isSubmitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pop(context, false),
                  child:
                      Text("Skip", style: TextStyle(color: DesignTokens.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
