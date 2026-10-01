import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';

final studyPinCategoriesProvider = StreamProvider<List<StudyPinCategory>>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return db.watchAllCategories();
});

final studyPinCategoryByIdProvider =
    FutureProvider.family<StudyPinCategory?, String?>((ref, id) async {
      if (id == null) return null;
      final db = ref.watch(databaseProvider);
      return db.getCategoryById(id);
    });

/// Map of categoryId → category for O(1) paint-time lookups.
final studyPinCategoryMapProvider =
    Provider<AsyncValue<Map<String, StudyPinCategory>>>((ref) {
      return ref
          .watch(studyPinCategoriesProvider)
          .whenData((list) => {for (final c in list) c.id: c});
    });
