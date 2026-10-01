import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../text/text_direction_utils.dart';

/// [TextField] whose [textDirection] follows typed content (BiDi-safe).
///
/// App chrome stays LTR; only the field content direction adapts.
class AutoDirectionTextField extends StatefulWidget {
  const AutoDirectionTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.autofocus = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.enabled,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final bool autofocus;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;

  @override
  State<AutoDirectionTextField> createState() => _AutoDirectionTextFieldState();
}

class _AutoDirectionTextFieldState extends State<AutoDirectionTextField> {
  TextEditingController? _owned;
  TextEditingController get _controller =>
      widget.controller ?? (_owned ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant AutoDirectionTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onText);
      if (widget.controller != null) {
        _owned?.dispose();
        _owned = null;
      }
      _controller.addListener(_onText);
    }
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = TextDirectionUtils.resolve(_controller.text);
    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      decoration: widget.decoration,
      style: widget.style,
      autofocus: widget.autofocus,
      readOnly: widget.readOnly,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      textCapitalization: widget.textCapitalization,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      enabled: widget.enabled,
      textDirection: direction,
      textAlign: direction == TextDirection.rtl
          ? TextAlign.right
          : TextAlign.start,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}
