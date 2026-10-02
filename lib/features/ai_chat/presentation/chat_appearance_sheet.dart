import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/chat_appearance_providers.dart';
import '../domain/chat_appearance.dart';

Future<void> showChatAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ChatAppearanceSheet(),
  );
}

class _ChatAppearanceSheet extends ConsumerWidget {
  const _ChatAppearanceSheet();

  static const _colors = <int>[
    0xffe8f0fe,
    0xffdff5e8,
    0xffffeadf,
    0xfffff3c4,
    0xffeee5ff,
    0xffffe2eb,
    0xffe7edf3,
    0xff263238,
  ];

  static const _backgrounds = <int>[
    0xfff7f8fa,
    0xfffff8e7,
    0xffedf7f4,
    0xffeef3ff,
    0xfff7efff,
    0xff202124,
    0xff101214,
    0xff000000,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAppearance = ref.watch(chatAppearanceProvider);
    final appearance = asyncAppearance.valueOrNull ?? ChatAppearance.defaults;
    final controller = ref.read(chatAppearanceProvider.notifier);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.xs,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chat appearance',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: controller.reset,
                    child: const Text('Reset'),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (asyncAppearance.isLoading)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  const _SectionTitle('Presets'),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final preset in ChatAppearancePreset.values)
                        ActionChip(
                          avatar: Icon(_presetIcon(preset), size: 18),
                          label: Text(_presetLabel(preset)),
                          onPressed: () => controller.applyPreset(preset),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle('Message layout'),
                  SegmentedButton<ChatMessageLayout>(
                    segments: const [
                      ButtonSegment(
                        value: ChatMessageLayout.bubbles,
                        icon: Icon(Icons.chat_bubble_outline),
                        label: Text('Bubbles'),
                      ),
                      ButtonSegment(
                        value: ChatMessageLayout.fullWidth,
                        icon: Icon(Icons.view_agenda_outlined),
                        label: Text('Full width'),
                      ),
                    ],
                    selected: {appearance.layout},
                    onSelectionChanged: (selection) {
                      controller.update(
                        appearance.copyWith(layout: selection.single),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show message avatars'),
                    value: appearance.showAvatars,
                    onChanged: (value) => controller.update(
                      appearance.copyWith(showAvatars: value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SliderSetting(
                    title: 'Message text size',
                    valueLabel: '${(appearance.textScale * 100).round()}%',
                    value: appearance.textScale,
                    minimum: 0.8,
                    maximum: 1.5,
                    divisions: 14,
                    onChanged: (value) => controller.update(
                      appearance.copyWith(textScale: value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle('Your prompts'),
                  _ColorChoices(
                    values: _colors,
                    selected: appearance.userColorValue,
                    onSelected: (value) => controller.update(
                      value == null
                          ? appearance.copyWith(clearUserColor: true)
                          : appearance.copyWith(userColorValue: value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _SectionTitle('AI responses'),
                  _ColorChoices(
                    values: _colors,
                    selected: appearance.assistantColorValue,
                    onSelected: (value) => controller.update(
                      value == null
                          ? appearance.copyWith(clearAssistantColor: true)
                          : appearance.copyWith(assistantColorValue: value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle('Chat background'),
                  DropdownButtonFormField<ChatBackgroundKind>(
                    initialValue: appearance.backgroundKind,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ChatBackgroundKind.theme,
                        child: Text('App theme'),
                      ),
                      DropdownMenuItem(
                        value: ChatBackgroundKind.solid,
                        child: Text('Solid color'),
                      ),
                      DropdownMenuItem(
                        value: ChatBackgroundKind.gradient,
                        child: Text('Gradient'),
                      ),
                      DropdownMenuItem(
                        value: ChatBackgroundKind.image,
                        child: Text('Image'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      controller.update(
                        appearance.copyWith(backgroundKind: value),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (appearance.backgroundKind == ChatBackgroundKind.solid)
                    _ColorChoices(
                      values: _backgrounds,
                      selected: appearance.backgroundColorValue,
                      includeThemeDefault: false,
                      onSelected: (value) => controller.update(
                        appearance.copyWith(
                          backgroundColorValue: value ?? _backgrounds.first,
                        ),
                      ),
                    ),
                  if (appearance.backgroundKind == ChatBackgroundKind.gradient)
                    _GradientChoices(
                      start: appearance.gradientStartValue,
                      end: appearance.gradientEndValue,
                      onSelected: (colors) => controller.update(
                        appearance.copyWith(
                          gradientStartValue: colors.$1,
                          gradientEndValue: colors.$2,
                        ),
                      ),
                    ),
                  if (appearance.backgroundKind == ChatBackgroundKind.image)
                    _ImageControls(
                      appearance: appearance,
                      onChoose: () async {
                        try {
                          await controller.chooseBackgroundImage();
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not use that background image.',
                              ),
                            ),
                          );
                        }
                      },
                      onClear: controller.clearBackgroundImage,
                      onOpacityChanged: (value) => controller.update(
                        appearance.copyWith(backgroundImageOpacity: value),
                      ),
                      onBlurChanged: (value) => controller.update(
                        appearance.copyWith(backgroundImageBlur: value),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Appearance settings are stored only on this device and '
                    'never change what is sent to the AI.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _presetLabel(ChatAppearancePreset preset) => switch (preset) {
    ChatAppearancePreset.defaultStyle => 'Default',
    ChatAppearancePreset.chatGpt => 'ChatGPT',
    ChatAppearancePreset.minimal => 'Minimal',
    ChatAppearancePreset.amoled => 'AMOLED',
  };

  static IconData _presetIcon(ChatAppearancePreset preset) => switch (preset) {
    ChatAppearancePreset.defaultStyle => Icons.auto_awesome_outlined,
    ChatAppearancePreset.chatGpt => Icons.view_agenda_outlined,
    ChatAppearancePreset.minimal => Icons.horizontal_rule,
    ChatAppearancePreset.amoled => Icons.dark_mode_outlined,
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _ColorChoices extends StatelessWidget {
  const _ColorChoices({
    required this.values,
    required this.selected,
    required this.onSelected,
    this.includeThemeDefault = true,
  });

  final List<int> values;
  final int? selected;
  final ValueChanged<int?> onSelected;
  final bool includeThemeDefault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (includeThemeDefault)
          _ColorButton(
            label: 'Theme default',
            color: theme.colorScheme.surface,
            selected: selected == null,
            icon: Icons.auto_awesome,
            onTap: () => onSelected(null),
          ),
        for (final value in values)
          _ColorButton(
            label: 'Select color',
            color: Color(value),
            selected: selected == value,
            onTap: () => onSelected(value),
          ),
      ],
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: icon == null
              ? selected
                    ? Icon(
                        Icons.check,
                        size: 20,
                        color: color.computeLuminance() > 0.45
                            ? Colors.black
                            : Colors.white,
                      )
                    : null
              : Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _GradientChoices extends StatelessWidget {
  const _GradientChoices({
    required this.start,
    required this.end,
    required this.onSelected,
  });

  static const _gradients = <(int, int)>[
    (0xffeef3ff, 0xfffff1f5),
    (0xffe8f5e9, 0xffe3f2fd),
    (0xfffff3e0, 0xfff3e5f5),
    (0xff182848, 0xff4b6cb7),
    (0xff232526, 0xff414345),
  ];

  final int? start;
  final int? end;
  final ValueChanged<(int, int)> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final colors in _gradients)
          Semantics(
            button: true,
            selected: start == colors.$1 && end == colors.$2,
            label: 'Select gradient',
            child: InkWell(
              onTap: () => onSelected(colors),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 72,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [Color(colors.$1), Color(colors.$2)],
                  ),
                  border: Border.all(
                    color: start == colors.$1 && end == colors.$2
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: start == colors.$1 && end == colors.$2 ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String valueLabel;
  final double value;
  final double minimum;
  final double maximum;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            Text(valueLabel),
          ],
        ),
        Slider(
          value: value,
          min: minimum,
          max: maximum,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ImageControls extends StatelessWidget {
  const _ImageControls({
    required this.appearance,
    required this.onChoose,
    required this.onClear,
    required this.onOpacityChanged,
    required this.onBlurChanged,
  });

  final ChatAppearance appearance;
  final VoidCallback onChoose;
  final VoidCallback onClear;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<double> onBlurChanged;

  @override
  Widget build(BuildContext context) {
    final hasImage = appearance.backgroundImagePath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onChoose,
                icon: const Icon(Icons.image_outlined),
                label: Text(hasImage ? 'Change image' : 'Choose image'),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                tooltip: 'Remove background image',
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
        _SliderSetting(
          title: 'Image visibility',
          valueLabel: '${(appearance.backgroundImageOpacity * 100).round()}%',
          value: appearance.backgroundImageOpacity,
          minimum: 0,
          maximum: 0.8,
          divisions: 16,
          onChanged: onOpacityChanged,
        ),
        _SliderSetting(
          title: 'Image blur',
          valueLabel: appearance.backgroundImageBlur.toStringAsFixed(0),
          value: appearance.backgroundImageBlur,
          minimum: 0,
          maximum: 20,
          divisions: 20,
          onChanged: onBlurChanged,
        ),
      ],
    );
  }
}
