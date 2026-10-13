import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_execution_selection.dart';
import '../../ai_assistant/presentation/pick_ai_model.dart';
import '../data/pdf_ai_material_providers.dart';
import '../domain/pdf_ai_translation.dart';

Future<void> setPdfAiAlsoPersian(WidgetRef ref, bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(PdfAiAlsoPersian.key, value);
  ref.invalidate(pdfAiAlsoPersianProvider);
}

/// Translates [source] into Persian, reporting progress through
/// [pdfAiTranslationProgressProvider] so any open reader can show it.
///
/// Uses the provider container directly so the work finishes (and is
/// reported) even if the widget that started it is replaced meanwhile.
Future<bool> translatePdfAiVersion(
  BuildContext context,
  WidgetRef ref,
  PdfAiMaterial source, {
  AiExecutionSelection? selection,
  bool switchToPersian = true,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final chosen =
      selection ?? await pickAiModel(context, ref, title: 'Translate with');
  if (chosen == null) return false;
  final progress = container.read(
    pdfAiTranslationProgressProvider(source.id).notifier,
  );
  try {
    await container
        .read(pdfAiTranslationServiceProvider)
        .translate(
          source: source,
          selection: chosen,
          onProgress: (done, total) => progress.state = '$done/$total',
        );
    if (switchToPersian) {
      container.read(pdfAiLanguageProvider(source.materialId).notifier).state =
          PdfAiLanguage.persian;
    }
    messenger?.showSnackBar(
      const SnackBar(content: Text('Persian translation is ready.')),
    );
    return true;
  } on AiException catch (error) {
    messenger?.showSnackBar(SnackBar(content: Text(error.message)));
  } on Object catch (error) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          error is StateError && error.message.contains('already')
              ? error.message
              : 'Could not translate this version. Please try again.',
        ),
      ),
    );
  } finally {
    progress.state = null;
  }
  return false;
}
