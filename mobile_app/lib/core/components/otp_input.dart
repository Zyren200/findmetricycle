import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../theme/design_tokens.dart";

/// Six code boxes over one hidden field: type or paste (SMS / email
/// autofill works), the next box glows orange, filled boxes pop slightly.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.autofocus = true,
    this.error = false,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;
  final bool error;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(OtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.dispose();
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return Semantics(
      label: "${widget.length}-digit code",
      value: "${code.length} of ${widget.length} digits entered",
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _box(i, code)),
                ],
              ],
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  onChanged: (v) {
                    widget.onChanged?.call(v);
                    if (v.length == widget.length) {
                      widget.onCompleted?.call(v);
                    }
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    counterText: "",
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(int i, String code) {
    final filled = i < code.length;
    final next = i == code.length && _focus.hasFocus;
    final border = widget.error
        ? DesignTokens.sos
        : next
            ? DesignTokens.primaryBright
            : filled
                ? DesignTokens.ink2
                : DesignTokens.lineStrong;
    return AnimatedScale(
      duration: const Duration(milliseconds: 300),
      curve: DesignTokens.spring,
      scale: filled ? 1.03 : 1,
      child: AnimatedContainer(
        duration: DesignTokens.quick,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? DesignTokens.surface : DesignTokens.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.5),
          boxShadow: next && !widget.error
              ? [
                  BoxShadow(
                      color: DesignTokens.primaryBright.withAlpha(36),
                      spreadRadius: 4)
                ]
              : null,
        ),
        child: Text(
          filled ? code[i] : "",
          style: TextStyle(
            color: DesignTokens.ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            fontFeatures: DesignTokens.tabular,
          ),
        ),
      ),
    );
  }
}
