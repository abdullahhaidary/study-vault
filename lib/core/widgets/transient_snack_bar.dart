import 'package:flutter/material.dart';

const transientSnackBarDuration = Duration(seconds: 3);

/// A toast-style message that always dismisses itself after a short delay.
class TransientSnackBar extends SnackBar {
  const TransientSnackBar({
    super.key,
    required super.content,
    super.action,
    super.duration = transientSnackBarDuration,
  }) : super(persist: false);
}
