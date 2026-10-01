import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/built_in_data.dart';
import '../../../core/database/database_provider.dart';

const _uuid = Uuid();

final favoritesProvider = StreamProvider<List<Favorite>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllFavorites();
});

final favoritesOfTypeProvider = StreamProvider.family<List<Favorite>, String>((
  ref,
  entityType,
) {
  final db = ref.watch(databaseProvider);
  return db.watchFavoritesOfType(entityType);
});

final isFavoriteProvider =
    StreamProvider.family<bool, ({String type, String id})>((ref, key) {
      final db = ref.watch(databaseProvider);
      return db.watchIsFavorite(key.type, key.id);
    });

Future<void> toggleFavorite(
  WidgetRef ref, {
  required String entityType,
  required String entityId,
}) async {
  final db = ref.read(databaseProvider);
  final existing = await db.isFavorite(entityType, entityId);
  if (existing) {
    await db.removeFavorite(entityType, entityId);
  } else {
    await db.addFavorite(
      id: _uuid.v4(),
      entityType: entityType,
      entityId: entityId,
    );
  }
}

Future<void> setFavorite(
  WidgetRef ref, {
  required String entityType,
  required String entityId,
  required bool favorite,
}) async {
  final db = ref.read(databaseProvider);
  final existing = await db.isFavorite(entityType, entityId);
  if (favorite && !existing) {
    await db.addFavorite(
      id: _uuid.v4(),
      entityType: entityType,
      entityId: entityId,
    );
  } else if (!favorite && existing) {
    await db.removeFavorite(entityType, entityId);
  }
}

/// Convenience keys for [isFavoriteProvider].
({String type, String id}) favoriteKey(String type, String id) =>
    (type: type, id: id);

abstract final class FavoriteKeys {
  static ({String type, String id}) class_(String id) =>
      favoriteKey(FavoriteEntityType.class_, id);
  static ({String type, String id}) subject(String id) =>
      favoriteKey(FavoriteEntityType.subject, id);
  static ({String type, String id}) lesson(String id) =>
      favoriteKey(FavoriteEntityType.lesson, id);
  static ({String type, String id}) material(String id) =>
      favoriteKey(FavoriteEntityType.material, id);
  static ({String type, String id}) studyPin(String id) =>
      favoriteKey(FavoriteEntityType.studyPin, id);
}
