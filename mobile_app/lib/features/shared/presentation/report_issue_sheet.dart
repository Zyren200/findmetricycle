import "package:flutter/material.dart";

import "../../../core/components/index.dart";
import "../../../core/theme/design_tokens.dart";

/// What a passenger's report can be about (keys match the server's).
const Map<String, String> kPassengerReportCategories = {
  "booking_issue": "Booking issue",
  "driver_issue": "Driver issue",
  "fare_dispute": "Fare issue",
  "safety_concern": "Safety concern",
  "app_issue": "App issue",
  "account_issue": "Account issue",
  "other": "Other",
};

/// What a rider's report can be about (keys match the server's).
const Map<String, String> kDriverReportCategories = {
  "no_show": "Passenger no-show",
  "incorrect_pickup": "Incorrect pickup",
  "fare_dispute": "Fare dispute",
  "safety_concern": "Safety concern",
  "passenger_behavior": "Passenger behavior",
  "other": "Other",
};

/// "Report a problem": pick what it's about, describe it. Pops the choice
/// and the description, or null when cancelled. [about] names the ride the
/// report is tied to, when there is one.
Future<({String category, String description})?> showReportIssueSheet(
  BuildContext context, {
  required Map<String, String> categories,
  String? about,
}) {
  return showSunSheet<({String category, String description})>(
    context,
    builder: (_) => _ReportIssueCard(categories: categories, about: about),
  );
}

/// Owns its text controller so it's disposed only after the sheet has
/// fully closed. Disposing it as soon as the sheet returned crashed the
/// TextField still rebuilding during the closing animation (red screen:
/// "TextEditingController was used after being disposed").
class _ReportIssueCard extends StatefulWidget {
  const _ReportIssueCard({required this.categories, this.about});

  final Map<String, String> categories;
  final String? about;

  @override
  State<_ReportIssueCard> createState() => _ReportIssueCardState();
}

class _ReportIssueCardState extends State<_ReportIssueCard> {
  late String _category = widget.categories.keys.first;
  final _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final description = _description.text.trim();
    return SunSheetCard(
      title: "Report a problem",
      message: widget.about ??
          "Tell the FindMeTricycle admin what happened. They'll review it.",
      align: CrossAxisAlignment.stretch,
      content: [
        ChoiceList(
          options: [for (final e in widget.categories.entries) (e.key, e.value)],
          value: _category,
          onChanged: (v) => setState(() => _category = v),
        ),
        SunField(
          label: "What happened?",
          controller: _description,
          hint: "Describe what happened…",
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
      ],
      actions: [
        SunButton(
          label: "Send report",
          onPressed: description.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    (category: _category, description: description),
                  ),
        ),
        SunButton(
          label: "Cancel",
          tone: SunTone.quiet,
          height: 48,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

/// Radio-style list of choices inside a sheet (report topics, cancel
/// reasons).
class ChoiceList extends StatelessWidget {
  const ChoiceList(
      {super.key,
      required this.options,
      required this.value,
      required this.onChanged});

  final List<(String value, String label)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (v, label) in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              selected: v == value,
              button: true,
              child: Pressable(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: DesignTokens.quick,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: v == value
                        ? DesignTokens.primarySoft
                        : DesignTokens.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      width: 1.5,
                      color: v == value
                          ? DesignTokens.primaryBright
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(label,
                            style: TextStyle(
                                color: DesignTokens.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                      Icon(
                        v == value
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 20,
                        color: v == value
                            ? DesignTokens.primaryText
                            : DesignTokens.ink2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
