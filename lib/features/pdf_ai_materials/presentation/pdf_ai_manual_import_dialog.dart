import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_spacing.dart';
import '../domain/pdf_ai_material_models.dart';
import '../domain/pdf_ai_versioning.dart';

Future<String?> showPdfAiManualImportDialog(
  BuildContext context, {
  required PdfAiMaterialType type,
  String? pdfTitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _PdfAiManualImportDialog(type: type, pdfTitle: pdfTitle),
  );
}

class _PdfAiManualImportDialog extends StatefulWidget {
  const _PdfAiManualImportDialog({required this.type, this.pdfTitle});

  final PdfAiMaterialType type;
  final String? pdfTitle;

  @override
  State<_PdfAiManualImportDialog> createState() =>
      _PdfAiManualImportDialogState();
}

class _PdfAiManualImportDialogState extends State<_PdfAiManualImportDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyInstruction() async {
    await Clipboard.setData(
      ClipboardData(
        text: PdfAiPromptBuilder.externalInstruction(
          type: widget.type,
          pdfTitle: widget.pdfTitle,
        ),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.type.shortName} instruction copied. Paste it into ChatGPT, then paste the JSON here.',
        ),
      ),
    );
  }

  void _import() {
    try {
      final markdown = PdfAiManualJson.extractMarkdown(
        _controller.text,
        widget.type,
      );
      Navigator.pop(context, markdown);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.type.shortName} from JSON'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Copy the ${widget.type.shortName} instruction, generate JSON '
                'with ChatGPT (or another model), then paste that JSON here.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _copyInstruction,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy instruction'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _controller,
                minLines: 6,
                maxLines: 12,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  alignLabelWithHint: true,
                  labelText: 'JSON',
                  hintText:
                      '{ "format": "${PdfAiManualJson.format}", "type": '
                      '"${widget.type.storageValue}", "content": "..." }',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _import, child: const Text('Add')),
      ],
    );
  }
}
