import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../../ai_assistant/presentation/pick_ai_model.dart';
import '../../pdf_ai_materials/data/pdf_ai_material_providers.dart';
import '../../pdf_ai_materials/services/pdf_ai_material_service.dart';
import '../domain/book_ai_input.dart';

class BookAiRequest {
  const BookAiRequest(this.selection, this.inputMode);
  final AiExecutionSelection selection;
  final BookAiInputMode inputMode;
}

Future<BookAiRequest?> pickBookAiRequest(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required int pageCount,
  required String sourceDescription,
}) async {
  final selection = await pickAiModel(context, ref, title: title);
  if (selection == null || !context.mounted) return null;
  // These providers always use extracted pages; avoid an unnecessary dialog.
  if (selection.provider == AiProviderId.deepseek ||
      selection.provider == AiProviderId.pocket) {
    return BookAiRequest(selection, BookAiInputMode.extractedText);
  }
  final mode = await chooseBookInputMode(
    context,
    ref,
    selection: selection,
    pageCount: pageCount,
    sourceDescription: sourceDescription,
  );
  return mode == null ? null : BookAiRequest(selection, mode);
}

Future<BookAiInputMode?> chooseBookInputMode(
  BuildContext context,
  WidgetRef ref, {
  required AiExecutionSelection selection,
  required int pageCount,
  required String sourceDescription,
  BookAiInputMode initial = BookAiInputMode.extractedText,
}) async {
  final client = ref.read(pdfAiCompletionClientProvider);
  String? unavailable;
  int? pageLimit;
  if (client is PdfAiFileCompletionClient) {
    try {
      final limit = await (client as PdfAiFileCompletionClient).pdfPageLimit(
        selection,
      );
      pageLimit = limit;
      if (pageCount > limit) {
        unavailable =
            'This source has $pageCount pages. The selected endpoint allows $pageLimit per request. Choose a smaller chapter/range or use extracted text.';
      }
    } on Object catch (error) {
      unavailable = aiErrorMessage(error);
    }
  } else {
    unavailable =
        'PDF attachments are unavailable for this model. Extracted text is supported.';
  }
  if (!context.mounted) return null;
  var selected = unavailable == null ? initial : BookAiInputMode.extractedText;
  return showDialog<BookAiInputMode>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: const Text('Send book content'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sourceDescription),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selected == BookAiInputMode.extractedText
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: const Text('Extracted text'),
                  subtitle: const Text(
                    'Send relevant page text. Works with DeepSeek, Gemini, Pocket, and custom models.',
                  ),
                  onTap: () =>
                      setLocal(() => selected = BookAiInputMode.extractedText),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selected == BookAiInputMode.pdfAttachment
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  enabled: unavailable == null,
                  title: const Text('Attach PDF'),
                  subtitle: Text(
                    unavailable ??
                        'Send the PDF with diagrams and page layout. Up to $pageLimit pages and 20 MiB.',
                  ),
                  onTap: unavailable == null
                      ? () => setLocal(
                          () => selected = BookAiInputMode.pdfAttachment,
                        )
                      : null,
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
          FilledButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Use this mode'),
          ),
        ],
      ),
    ),
  );
}
