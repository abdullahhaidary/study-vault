import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Renders markdown horizontal rules (`--`, `---`, `***`, `___`) in Quill.
class DividerEmbedBuilder extends EmbedBuilder {
  const DividerEmbedBuilder();

  static const type = 'divider';

  @override
  String get key => type;

  @override
  String toPlainText(Embed node) => '\n───\n';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        thickness: 1,
        color: theme.colorScheme.outlineVariant,
      ),
    );
  }
}
