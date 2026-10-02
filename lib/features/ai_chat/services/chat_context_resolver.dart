import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/storage/material_storage.dart';
import '../../ai_questions/domain/question_source.dart';
import '../../ai_questions/services/pdf_text_extractor.dart';
import '../../search/domain/study_search_result.dart';
import '../../study_pins/domain/study_note_codec.dart';
import '../domain/ai_chat_models.dart';

/// Resolves Study Vault entities into [AiContextItem]s with packed text.
class ChatContextResolver {
  ChatContextResolver({
    required this.db,
    this.maxCharsPerAttachment = 24000,
    this.maxCharsCombined = 40000,
    this.extractPages = PdfTextExtractor.extractPages,
    this.resolveMaterialPath,
  });

  final AppDatabase db;
  final int maxCharsPerAttachment;
  final int maxCharsCombined;

  /// Injectable for tests.
  final Future<List<SourcePageText>> Function({
    required String filePath,
    Set<int>? pageNumbers,
  })
  extractPages;

  final Future<String> Function({
    required String lessonId,
    required String storedFileName,
  })?
  resolveMaterialPath;

  /// Build a draft chip from a search hit (no extraction yet).
  AiContextItem draftFromSearch(StudySearchResult hit) {
    final kind = AiContextKindX.fromSearchKind(hit.kind);
    if (kind == null) {
      throw ArgumentError('Unsupported mention kind: ${hit.kind}');
    }
    return AiContextItem(
      kind: kind,
      id: hit.id,
      title: hit.title,
      lessonId: hit.lessonId,
      materialId:
          hit.materialId ?? (kind == AiContextKind.material ? hit.id : null),
    );
  }

  /// Resolve and pack all [drafts] at send time.
  Future<List<AiContextItem>> resolveAll(List<AiContextItem> drafts) async {
    final resolved = <AiContextItem>[];
    var remaining = maxCharsCombined;
    for (final draft in drafts) {
      if (remaining <= 0) {
        resolved.add(
          draft.copyWith(
            truncated: true,
            emptyReason: 'Skipped: combined context limit reached.',
            clearPackedText: true,
          ),
        );
        continue;
      }
      final item = await resolveOne(draft, budget: remaining);
      resolved.add(item);
      final used = item.packedText?.length ?? 0;
      remaining -= used;
    }
    return resolved;
  }

  Future<AiContextItem> resolveOne(AiContextItem draft, {int? budget}) async {
    final cap = (budget ?? maxCharsPerAttachment).clamp(
      0,
      maxCharsPerAttachment,
    );
    return switch (draft.kind) {
      AiContextKind.material => _resolveMaterial(draft, cap),
      AiContextKind.lesson => _resolveLesson(draft, cap),
      AiContextKind.note => _resolveNote(draft, cap),
      AiContextKind.studyPin => _resolvePin(draft, cap),
    };
  }

  Future<AiContextItem> _resolveMaterial(AiContextItem draft, int cap) async {
    final material = await db.getMaterialById(draft.id);
    if (material == null) {
      return draft.copyWith(
        emptyReason: 'Material not found on this device.',
        clearPackedText: true,
      );
    }
    return _extractMaterial(
      material: material,
      title: draft.title.isEmpty ? material.title : draft.title,
      kind: AiContextKind.material,
      id: material.id,
      cap: cap,
    );
  }

  Future<AiContextItem> _resolveLesson(AiContextItem draft, int cap) async {
    final lesson = await db.getLessonById(draft.id);
    if (lesson == null) {
      return draft.copyWith(
        emptyReason: 'Lesson not found on this device.',
        clearPackedText: true,
      );
    }
    final materials =
        await (db.select(db.lessonMaterials)
              ..where((t) => t.lessonId.equals(draft.id))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    if (materials.isEmpty) {
      return draft.copyWith(
        title: lesson.name,
        lessonId: lesson.id,
        emptyReason: 'This lesson has no materials.',
        clearPackedText: true,
      );
    }

    final buffer = StringBuffer();
    final pages = <int>[];
    var truncated = false;
    var anyText = false;
    var remaining = cap;

    for (final material in materials) {
      if (remaining <= 0) {
        truncated = true;
        break;
      }
      final piece = await _extractMaterial(
        material: material,
        title: material.title,
        kind: AiContextKind.material,
        id: material.id,
        cap: remaining,
      );
      if (piece.emptyReason != null && (piece.packedText?.isEmpty ?? true)) {
        buffer.writeln();
        buffer.writeln('--- ${material.title} ---');
        buffer.writeln('(${piece.emptyReason})');
        continue;
      }
      final body = piece.packedText?.trim() ?? '';
      if (body.isEmpty) continue;
      anyText = true;
      buffer.writeln();
      buffer.writeln('--- ${material.title} ---');
      buffer.writeln(body);
      pages.addAll(piece.pageNumbers);
      if (piece.truncated) truncated = true;
      remaining -= body.length;
    }

    final packed = buffer.toString().trim();
    if (!anyText) {
      return draft.copyWith(
        title: lesson.name,
        lessonId: lesson.id,
        emptyReason: 'No extractable text in this lesson’s materials.',
        clearPackedText: true,
      );
    }

    final clipped = _clip(packed, cap);
    return AiContextItem(
      kind: AiContextKind.lesson,
      id: lesson.id,
      title: lesson.name,
      lessonId: lesson.id,
      pageNumbers: pages,
      truncated: truncated || clipped.truncated,
      packedText: clipped.text,
    );
  }

  Future<AiContextItem> _resolveNote(AiContextItem draft, int cap) async {
    final note = await db.getStudyNoteById(draft.id);
    if (note == null) {
      return draft.copyWith(
        emptyReason: 'Note not found on this device.',
        clearPackedText: true,
      );
    }
    final plain =
        (note.plainTextContent ?? StudyNoteCodec.plainTextPreview(note.content))
            .trim();
    if (plain.isEmpty) {
      return draft.copyWith(
        title: note.title,
        lessonId: note.lessonId,
        emptyReason: 'This note has no text.',
        clearPackedText: true,
      );
    }
    final clipped = _clip(plain, cap);
    return AiContextItem(
      kind: AiContextKind.note,
      id: note.id,
      title: note.title,
      lessonId: note.lessonId,
      truncated: clipped.truncated,
      packedText: clipped.text,
    );
  }

  Future<AiContextItem> _resolvePin(AiContextItem draft, int cap) async {
    final pin = await db.getStudyPinById(draft.id);
    if (pin == null || pin.deletedAt != null) {
      return draft.copyWith(
        emptyReason: 'Pin not found on this device.',
        clearPackedText: true,
      );
    }
    final material = await db.getMaterialById(pin.resourceId);
    final parts = <String>[
      pin.shortText.trim(),
      if ((pin.selectedText ?? '').trim().isNotEmpty)
        'Selected: ${pin.selectedText!.trim()}',
      if ((pin.fullExplanationPlainText ?? '').trim().isNotEmpty)
        pin.fullExplanationPlainText!.trim()
      else if ((pin.fullExplanation ?? '').trim().isNotEmpty)
        StudyNoteCodec.plainTextPreview(pin.fullExplanation).trim(),
    ].where((s) => s.isNotEmpty).toList();

    if (parts.isEmpty) {
      return draft.copyWith(
        title: pin.shortText,
        materialId: pin.resourceId,
        lessonId: material?.lessonId,
        emptyReason: 'This pin has no text.',
        clearPackedText: true,
      );
    }

    final packed = parts.join('\n\n');
    final clipped = _clip(packed, cap);
    return AiContextItem(
      kind: AiContextKind.studyPin,
      id: pin.id,
      title: pin.shortText,
      materialId: pin.resourceId,
      lessonId: material?.lessonId,
      pageNumbers: pin.pageNumber == null ? const [] : [pin.pageNumber!],
      truncated: clipped.truncated,
      packedText: clipped.text,
    );
  }

  Future<AiContextItem> _extractMaterial({
    required LessonMaterial material,
    required String title,
    required AiContextKind kind,
    required String id,
    required int cap,
  }) async {
    final mime = material.mimeType.toLowerCase();
    if (!mime.contains('pdf')) {
      return AiContextItem(
        kind: kind,
        id: id,
        title: title,
        lessonId: material.lessonId,
        materialId: material.id,
        emptyReason: 'No extractable text in this file.',
      );
    }

    final pathResolver = resolveMaterialPath ?? MaterialStorage.absolutePath;
    final path = await pathResolver(
      lessonId: material.lessonId,
      storedFileName: material.storedFileName,
    );
    if (!await File(path).exists()) {
      return AiContextItem(
        kind: kind,
        id: id,
        title: title,
        lessonId: material.lessonId,
        materialId: material.id,
        emptyReason: 'File is missing on this device.',
      );
    }

    try {
      final pages = await extractPages(filePath: path);
      if (pages.isEmpty) {
        return AiContextItem(
          kind: kind,
          id: id,
          title: title,
          lessonId: material.lessonId,
          materialId: material.id,
          emptyReason: 'No text in this file.',
        );
      }
      final source = QuestionSourceBuilder.fromMaterial(
        pages: pages,
        materialId: material.id,
        lessonId: material.lessonId,
        filePath: path,
      );
      if (source.isEmpty) {
        return AiContextItem(
          kind: kind,
          id: id,
          title: title,
          lessonId: material.lessonId,
          materialId: material.id,
          emptyReason: 'No text in this file.',
        );
      }
      final clipped = _clip(source.text, cap);
      return AiContextItem(
        kind: kind,
        id: id,
        title: title,
        lessonId: material.lessonId,
        materialId: material.id,
        pageNumbers: source.pageNumbers,
        truncated: clipped.truncated,
        packedText: clipped.text,
      );
    } on Object {
      return AiContextItem(
        kind: kind,
        id: id,
        title: title,
        lessonId: material.lessonId,
        materialId: material.id,
        emptyReason: 'Could not read this PDF.',
      );
    }
  }

  ({String text, bool truncated}) _clip(String text, int cap) {
    if (cap <= 0) return (text: '', truncated: text.isNotEmpty);
    if (text.length <= cap) return (text: text, truncated: false);
    return (text: '${text.substring(0, cap).trimRight()}…', truncated: true);
  }
}
