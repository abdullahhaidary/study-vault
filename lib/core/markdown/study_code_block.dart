import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/highlight.dart' show highlight, Node;

import '../theme/app_spacing.dart';

/// ChatGPT-style fenced code block: language chip, copy, syntax colors.
class StudyCodeBlock extends StatelessWidget {
  const StudyCodeBlock({
    super.key,
    required this.source,
    this.language,
  });

  final String source;
  final String? language;

  /// Maps common fence aliases to highlight.js language ids.
  static String? normalizeLanguage(String? raw) {
    final lang = raw?.trim().toLowerCase();
    if (lang == null || lang.isEmpty) return null;
    return switch (lang) {
      'js' || 'node' || 'nodejs' => 'javascript',
      'ts' || 'tsx' => 'typescript',
      'py' || 'python3' => 'python',
      'sh' || 'shell' || 'zsh' || 'bash' || 'console' => 'bash',
      'yml' => 'yaml',
      'kt' || 'kts' => 'kotlin',
      'rs' => 'rust',
      'cs' || 'csharp' => 'cs',
      'c++' || 'cpp' || 'cxx' => 'cpp',
      'objc' || 'objective-c' => 'objectivec',
      'plaintext' || 'text' || 'txt' => 'plaintext',
      'md' || 'markdown' => 'markdown',
      'jsonc' => 'json',
      'dockerfile' => 'docker',
      _ => lang,
    };
  }

  static String displayLanguage(String? raw) {
    final normalized = normalizeLanguage(raw);
    if (normalized == null) return 'Code';
    return switch (normalized) {
      'javascript' => 'JavaScript',
      'typescript' => 'TypeScript',
      'python' => 'Python',
      'bash' => 'Shell',
      'csharp' || 'cs' => 'C#',
      'cpp' => 'C++',
      'objectivec' => 'Objective-C',
      'plaintext' => 'Plain text',
      'markdown' => 'Markdown',
      'yaml' => 'YAML',
      'json' => 'JSON',
      'sql' => 'SQL',
      'html' => 'HTML',
      'css' => 'CSS',
      'dart' => 'Dart',
      'kotlin' => 'Kotlin',
      'swift' => 'Swift',
      'rust' => 'Rust',
      'go' => 'Go',
      'java' => 'Java',
      'php' => 'PHP',
      'ruby' => 'Ruby',
      'docker' => 'Dockerfile',
      _ => normalized,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final highlightTheme = isDark ? atomOneDarkTheme : atomOneLightTheme;
    final surface =
        highlightTheme['root']?.backgroundColor ??
        (isDark ? const Color(0xFF282C34) : const Color(0xFFFAFAFA));
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.outlineVariant;
    final headerFg = isDark
        ? Colors.white.withValues(alpha: 0.72)
        : theme.colorScheme.onSurfaceVariant;
    final text = source.endsWith('\n')
        ? source.substring(0, source.length - 1)
        : source;
    final lang = normalizeLanguage(language);
    final label = displayLanguage(language);
    final codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.5,
      color: highlightTheme['root']?.color ?? theme.colorScheme.onSurface,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.55,
                    ),
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: headerFg,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _CopyButton(text: text, foreground: headerFg),
                ],
              ),
            ),
          ),
          _HorizontalCodeScroll(
            child: SelectableText.rich(
              TextSpan(
                style: codeStyle,
                children: _spansFor(text, language: lang, theme: highlightTheme),
              ),
              style: codeStyle,
            ),
          ),
        ],
      ),
    );
  }

  static List<InlineSpan> _spansFor(
    String source, {
    required String? language,
    required Map<String, TextStyle> theme,
  }) {
    final result = highlight.parse(source, language: language);
    final nodes = result.nodes;
    if (nodes == null || nodes.isEmpty) {
      return [TextSpan(text: source)];
    }
    return _convert(nodes, theme);
  }

  static List<TextSpan> _convert(
    List<Node> nodes,
    Map<String, TextStyle> theme,
  ) {
    final spans = <TextSpan>[];
    var current = spans;
    final stack = <List<TextSpan>>[];

    void traverse(Node node) {
      if (node.value != null) {
        current.add(
          node.className == null
              ? TextSpan(text: node.value)
              : TextSpan(text: node.value, style: theme[node.className!]),
        );
        return;
      }
      final children = node.children;
      if (children == null) return;
      final nested = <TextSpan>[];
      current.add(TextSpan(children: nested, style: theme[node.className ?? '']));
      stack.add(current);
      current = nested;
      for (final child in children) {
        traverse(child);
      }
      current = stack.isEmpty ? spans : stack.removeLast();
    }

    for (final node in nodes) {
      traverse(node);
    }
    return spans;
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text, required this.foreground});

  final String text;
  final Color foreground;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _copy,
      icon: Icon(
        _copied ? Icons.check : Icons.copy_outlined,
        size: 14,
        color: widget.foreground,
      ),
      label: Text(
        _copied ? 'Copied' : 'Copy',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: widget.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _HorizontalCodeScroll extends StatefulWidget {
  const _HorizontalCodeScroll({required this.child});

  final Widget child;

  @override
  State<_HorizontalCodeScroll> createState() => _HorizontalCodeScrollState();
}

class _HorizontalCodeScrollState extends State<_HorizontalCodeScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: widget.child,
      ),
    );
  }
}
