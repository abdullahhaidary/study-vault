import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

const _uuid = Uuid();

final bookmarksForMaterialProvider =
    StreamProvider.family<List<MaterialBookmark>, String>((ref, materialId) {
      final db = ref.watch(databaseProvider);
      return db.watchBookmarksForMaterial(materialId);
    });

final bookmarkForPageProvider =
    FutureProvider.family<MaterialBookmark?, (String, int)>((ref, args) async {
      final (materialId, page) = args;
      final db = ref.watch(databaseProvider);
      return db.getBookmarkForPage(materialId, page);
    });

final bookmarkCountForLessonProvider = FutureProvider.family<int, String>((
  ref,
  lessonId,
) async {
  final db = ref.watch(databaseProvider);
  return db.countBookmarksForLesson(lessonId);
});

/// Toggles a bookmark for [pageNumber]. Returns the created bookmark or null
/// when removed.
Future<MaterialBookmark?> toggleMaterialBookmark(
  WidgetRef ref, {
  required String materialId,
  required int pageNumber,
  String? title,
}) async {
  final db = ref.read(databaseProvider);
  final existing = await db.getBookmarkForPage(materialId, pageNumber);
  if (existing != null) {
    await db.deleteMaterialBookmark(existing.id);
    return null;
  }

  final now = DateTime.now();
  final id = _uuid.v4();
  final companion = MaterialBookmarksCompanion.insert(
    id: id,
    materialId: materialId,
    pageNumber: pageNumber,
    title: Value(title?.trim().isEmpty == true ? null : title?.trim()),
    createdAt: now,
    updatedAt: now,
  );
  await db.insertMaterialBookmark(companion);
  return db.getBookmarkForPage(materialId, pageNumber);
}

Future<void> updateBookmarkTitle(
  WidgetRef ref, {
  required MaterialBookmark bookmark,
  String? title,
}) async {
  final db = ref.read(databaseProvider);
  await db.updateMaterialBookmark(
    bookmark.copyWith(
      title: Value(title?.trim().isEmpty == true ? null : title?.trim()),
      updatedAt: DateTime.now(),
    ),
  );
}

Future<void> deleteMaterialBookmarkById(
  WidgetRef ref, {
  required String id,
}) async {
  final db = ref.read(databaseProvider);
  await db.deleteMaterialBookmark(id);
}
