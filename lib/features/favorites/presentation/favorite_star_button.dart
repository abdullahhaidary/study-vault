import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/favorites_providers.dart';

/// App-bar / inline favorite star toggle.
class FavoriteStarButton extends ConsumerWidget {
  const FavoriteStarButton({
    super.key,
    required this.entityType,
    required this.entityId,
    this.tooltip = 'Favorite',
  });

  final String entityType;
  final String entityId;
  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favAsync = ref.watch(
      isFavoriteProvider(favoriteKey(entityType, entityId)),
    );
    final isFav = favAsync.valueOrNull ?? false;

    return IconButton(
      tooltip: isFav ? 'Remove favorite' : tooltip,
      onPressed: () =>
          toggleFavorite(ref, entityType: entityType, entityId: entityId),
      icon: Icon(
        isFav ? Icons.star : Icons.star_border,
        color: isFav ? Theme.of(context).colorScheme.tertiary : null,
      ),
    );
  }
}
