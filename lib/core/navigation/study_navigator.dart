import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/storage/material_storage.dart';
import '../../features/lessons/data/materials_providers.dart';
import '../../features/flashcards/presentation/flashcards_list_screen.dart';
import '../../features/search/domain/study_search_result.dart';

/// Shared navigation for Search and Favorites destinations.
abstract final class StudyNavigator {
  static Future<void> openSearchResult(
    BuildContext context,
    WidgetRef ref,
    StudySearchResult result,
  ) {
    return openEntity(
      context,
      ref,
      kind: result.kind,
      id: result.id,
      classId: result.classId,
      subjectId: result.subjectId,
      lessonId: result.lessonId,
      materialId: result.materialId,
      materialTitle: result.materialTitle,
      mimeType: result.mimeType,
      pageNumber: result.pageNumber,
      focusPinId: result.kind == StudyEntityKind.studyPin ? result.id : null,
    );
  }

  static Future<void> openEntity(
    BuildContext context,
    WidgetRef ref, {
    required StudyEntityKind kind,
    required String id,
    String? classId,
    String? subjectId,
    String? lessonId,
    String? materialId,
    String? materialTitle,
    String? mimeType,
    int? pageNumber,
    String? focusPinId,
  }) async {
    switch (kind) {
      case StudyEntityKind.class_:
        await Navigator.of(
          context,
        ).pushNamed(AppRoutes.classDetails, arguments: id);
      case StudyEntityKind.subject:
        await Navigator.of(
          context,
        ).pushNamed(AppRoutes.subjectDetails, arguments: id);
      case StudyEntityKind.lesson:
        await Navigator.of(
          context,
        ).pushNamed(AppRoutes.lessonDetails, arguments: id);
      case StudyEntityKind.material:
        await _openMaterial(
          context,
          ref,
          materialId: id,
          title: materialTitle,
          mimeType: mimeType,
        );
      case StudyEntityKind.studyPin:
        final pinMaterialId = materialId;
        if (pinMaterialId == null) return;
        await _openMaterial(
          context,
          ref,
          materialId: pinMaterialId,
          title: materialTitle,
          mimeType: mimeType,
          initialPage: pageNumber,
          focusPinId: focusPinId ?? id,
        );
      case StudyEntityKind.note:
        await openNote(context, id: id);
      case StudyEntityKind.flashcard:
        await openFlashcard(context, id: id, lessonId: lessonId);
      case StudyEntityKind.bookmark:
        if (materialId == null || pageNumber == null) return;
        await _openMaterial(
          context,
          ref,
          materialId: materialId,
          title: materialTitle,
          mimeType: mimeType,
          initialPage: pageNumber,
        );
    }
  }

  static Future<void> openFavorite(
    BuildContext context,
    WidgetRef ref,
    Favorite favorite,
  ) async {
    final db = ref.read(databaseProvider);
    switch (favorite.entityType) {
      case 'class':
        await openEntity(
          context,
          ref,
          kind: StudyEntityKind.class_,
          id: favorite.entityId,
        );
      case 'subject':
        await openEntity(
          context,
          ref,
          kind: StudyEntityKind.subject,
          id: favorite.entityId,
        );
      case 'lesson':
        await openEntity(
          context,
          ref,
          kind: StudyEntityKind.lesson,
          id: favorite.entityId,
        );
      case 'material':
        await _openMaterial(context, ref, materialId: favorite.entityId);
      case 'studyPin':
        final pin = await db.getStudyPinById(favorite.entityId);
        if (pin == null || !context.mounted) return;
        final material = await db.getMaterialById(pin.resourceId);
        if (material == null || !context.mounted) return;
        await _openMaterial(
          context,
          ref,
          materialId: material.id,
          title: material.title,
          mimeType: material.mimeType,
          initialPage: pin.pageNumber,
          focusPinId: pin.id,
        );
      case 'note':
        await openNote(context, id: favorite.entityId);
      case 'flashcard':
        final card = await db.getFlashcardById(favorite.entityId);
        if (card == null || !context.mounted) return;
        await openFlashcard(context, id: card.id, lessonId: card.lessonId);
    }
  }

  static Future<void> openNote(BuildContext context, {required String id}) {
    return Navigator.of(context).pushNamed(AppRoutes.noteReader, arguments: id);
  }

  static Future<void> openFlashcard(
    BuildContext context, {
    required String id,
    String? lessonId,
  }) {
    return Navigator.of(context).pushNamed(
      AppRoutes.flashcardStudy,
      arguments: lessonId == null
          ? const FlashcardsListScope.all()
          : FlashcardsListScope.lesson(id: lessonId, title: 'Flashcards'),
    );
  }

  static Future<void> openSourcePin(
    BuildContext context,
    WidgetRef ref, {
    required String pinId,
  }) async {
    final db = ref.read(databaseProvider);
    final pin = await db.getStudyPinById(pinId);
    if (pin == null || !context.mounted) return;
    final material = await db.getMaterialById(pin.resourceId);
    if (material == null || !context.mounted) return;
    await _openMaterial(
      context,
      ref,
      materialId: material.id,
      title: material.title,
      mimeType: material.mimeType,
      initialPage: pin.pageNumber,
      focusPinId: pin.id,
    );
  }

  static Future<void> _openMaterial(
    BuildContext context,
    WidgetRef ref, {
    required String materialId,
    String? title,
    String? mimeType,
    int? initialPage,
    String? focusPinId,
  }) async {
    final db = ref.read(databaseProvider);
    final material = await db.getMaterialById(materialId);
    if (material == null || !context.mounted) return;

    final path = await MaterialStorage.absolutePath(
      lessonId: material.lessonId,
      storedFileName: material.storedFileName,
    );
    if (!context.mounted) return;

    final args = <String, String>{
      'resourceId': material.id,
      'title': title ?? material.title,
      'filePath': path,
      'focusPinId': ?focusPinId,
      'initialPage': ?initialPage?.toString(),
    };

    final route = isImageMimeType(mimeType ?? material.mimeType)
        ? AppRoutes.imageStudy
        : AppRoutes.pdfStudy;

    await Navigator.of(context).pushNamed(route, arguments: args);
  }
}
