enum ReorderDestination { start, previous, next, end }

List<String> reorderIds({
  required Iterable<String> ids,
  required String itemId,
  required ReorderDestination destination,
}) {
  final ordered = ids.toList();
  final currentIndex = ordered.indexOf(itemId);
  if (currentIndex < 0 || ordered.length < 2) return ordered;

  final targetIndex = switch (destination) {
    ReorderDestination.start => 0,
    ReorderDestination.previous => currentIndex - 1,
    ReorderDestination.next => currentIndex + 1,
    ReorderDestination.end => ordered.length - 1,
  }.clamp(0, ordered.length - 1);

  if (targetIndex == currentIndex) return ordered;
  ordered
    ..removeAt(currentIndex)
    ..insert(targetIndex, itemId);
  return ordered;
}
