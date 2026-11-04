import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/export/download_document_button.dart';
import '../data/materials_providers.dart';

/// Saves a lesson PDF or text document outside the app.
///
/// A Persian companion PDF asks which file to save.
Future<void> downloadLessonMaterial(
  BuildContext context,
  WidgetRef ref,
  LessonMaterial material,
) async {
  if (!isDocumentMimeType(material.mimeType)) return;
  var chosen = material;
  if (isPdfMimeType(material.mimeType)) {
    final persian = await ref.read(
      materialPersianVariantProvider(material.id).future,
    );
    if (!context.mounted) return;
    if (persian != null) {
      final picked = await showDialog<LessonMaterial>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Download PDF'),
          content: const Text(
            'This lesson has an original PDF and a Persian PDF.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, material),
              child: const Text('Original'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, persian),
              child: const Text('Persian'),
            ),
          ],
        ),
      );
      if (picked == null || !context.mounted) return;
      chosen = picked;
    }
  }
  if (!context.mounted) return;
  final path = await materialAbsolutePath(chosen);
  if (!context.mounted) return;
  await runDocumentDownload(
    context,
    DocumentFileRequest(
      fileName: chosen.title,
      sourcePath: path,
      kind: documentKindForMime(chosen.mimeType),
    ),
  );
}

DocumentFileKind documentKindForMime(String mimeType) {
  if (isPdfMimeType(mimeType)) return DocumentFileKind.pdf;
  if (isPlainTextMimeType(mimeType)) return DocumentFileKind.plainText;
  return DocumentFileKind.markdown;
}

DocumentFileKind documentKindForPath(String filePath) {
  return documentKindForMime(guessMimeType(filePath));
}
