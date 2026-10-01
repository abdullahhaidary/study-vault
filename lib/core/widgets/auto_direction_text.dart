import 'package:flutter/material.dart';

import '../text/text_direction_utils.dart';

/// [Text] that picks LTR/RTL from the first strong character in [data].
class AutoDirectionText extends StatelessWidget {
  const AutoDirectionText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
    this.strutStyle,
    this.textScaler,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;
  final StrutStyle? strutStyle;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    final direction = TextDirectionUtils.resolve(data);
    return Text(
      data,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      strutStyle: strutStyle,
      textScaler: textScaler,
      textDirection: direction,
      textAlign: direction == TextDirection.rtl
          ? TextAlign.right
          : TextAlign.left,
    );
  }
}

/// [SelectableText] with content-based direction.
class AutoDirectionSelectableText extends StatelessWidget {
  const AutoDirectionSelectableText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final direction = TextDirectionUtils.resolve(data);
    return SelectableText(
      data,
      style: style,
      maxLines: maxLines,
      textDirection: direction,
      textAlign: direction == TextDirection.rtl
          ? TextAlign.right
          : TextAlign.left,
    );
  }
}
