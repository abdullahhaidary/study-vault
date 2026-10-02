import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/auto_direction_text_field.dart';
import '../../data/voice_input_providers.dart';
import '../../domain/voice_dictation_merge.dart';
import '../../services/voice_input_service.dart';

/// Microphone control bound to a [TextEditingController].
///
/// Partial results replace the live speech segment only; existing text is kept.
/// Recognition never auto-sends.
class VoiceInputButton extends ConsumerStatefulWidget {
  const VoiceInputButton({
    super.key,
    required this.controller,
    this.enabled = true,
    this.compact = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool compact;
  final FocusNode? focusNode;

  @override
  ConsumerState<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends ConsumerState<VoiceInputButton> {
  VoiceDictationSession? _session;
  VoiceInputService? _boundService;
  bool _busyToggle = false;
  bool _ownsListen = false;

  @override
  void dispose() {
    if (_ownsListen) {
      // ignore: discarded_futures
      _boundService?.cancel();
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busyToggle || !widget.enabled) return;
    _busyToggle = true;
    try {
      final voice = ref.read(voiceInputServiceProvider);
      _boundService = voice;
      if (voice.isListening) {
        await voice.stop();
        if (mounted) {
          setState(() {
            _session = null;
            _ownsListen = false;
          });
        }
        return;
      }

      final ok = await voice.initialize();
      if (!mounted) return;
      if (!ok) {
        _showError(voice.lastError?.message);
        return;
      }

      final language = await ref
          .read(voiceAiSettingsStoreProvider)
          .getLanguage();
      if (!mounted) return;
      final localeId = voice.resolveLocaleId(language);

      final text = widget.controller.text;
      final selection = widget.controller.selection;
      final offset = selection.isValid
          ? selection.extentOffset.clamp(0, text.length)
          : text.length;
      _session = VoiceDictationSession.capture(
        text: text,
        cursorOffset: offset,
      );
      _ownsListen = true;

      await voice.start(
        localeId: localeId,
        onResult: (words, isFinal) {
          if (!mounted || _session == null) return;
          _session!.updateSpoken(words);
          final composed = _session!.composed;
          final caret = _session!.caretOffset;
          widget.controller.value = TextEditingValue(
            text: composed,
            selection: TextSelection.collapsed(offset: caret),
          );
          widget.focusNode?.requestFocus();
          if (isFinal) {
            setState(() {});
          }
        },
      );

      if (!mounted) return;
      if (voice.lastError != null && !voice.isListening) {
        _showError(voice.lastError!.message);
        setState(() {
          _session = null;
          _ownsListen = false;
        });
        return;
      }
      setState(() {});
    } finally {
      _busyToggle = false;
    }
  }

  void _showError(String? message) {
    if (!mounted || message == null || message.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(voiceInputServiceProvider);
    final listening = voice.isListening && _session != null;
    final theme = Theme.of(context);

    // When another owner stops listening, clear our session marker.
    if (!voice.isListening && _session != null && !_busyToggle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !voice.isListening) {
          setState(() {
            _session = null;
            _ownsListen = false;
          });
        }
      });
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: listening ? 'Stop voice input' : 'Start voice input',
          child: IconButton(
            tooltip: listening ? 'Tap to stop' : 'Tap to speak',
            onPressed: widget.enabled ? _toggle : null,
            icon: Icon(
              listening ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
              color: listening ? theme.colorScheme.error : null,
            ),
            iconSize: widget.compact ? 20 : 24,
            visualDensity: widget.compact
                ? VisualDensity.compact
                : VisualDensity.standard,
            style: listening
                ? IconButton.styleFrom(foregroundColor: theme.colorScheme.error)
                : null,
          ),
        ),
        if (listening)
          Text(
            'Listening…',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}

/// Shared Ask AI / custom prompt dialog with voice input.
Future<String?> showAiPromptDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String confirmLabel = 'Run',
  String initialText = '',
  int minLines = 2,
  int maxLines = 5,
}) async {
  final controller = TextEditingController(text: initialText);
  final focus = FocusNode();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AutoDirectionTextField(
                    controller: controller,
                    focusNode: focus,
                    autofocus: true,
                    minLines: minLines,
                    maxLines: maxLines,
                    decoration: InputDecoration(
                      hintText: hint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                VoiceInputButton(
                  controller: controller,
                  focusNode: focus,
                  compact: true,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  focus.dispose();
  controller.dispose();
  if (result == null || result.isEmpty) return null;
  return result;
}
