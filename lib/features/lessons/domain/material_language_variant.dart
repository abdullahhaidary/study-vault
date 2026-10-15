/// Helpers for original ↔ Persian companion PDF page mapping.
abstract final class MaterialLanguageVariant {
  static const persian = 'fa';

  /// Maps [page] from one language file onto another using each file's
  /// [pageOffset] (`persianPage = originalPage + offset`).
  static int mapPage({
    required int page,
    required int fromOffset,
    required int toOffset,
    int? toPageCount,
  }) {
    final logical = page - fromOffset;
    final mapped = logical + toOffset;
    if (toPageCount == null || toPageCount < 1) {
      return mapped < 1 ? 1 : mapped;
    }
    if (mapped < 1) return 1;
    if (mapped > toPageCount) return toPageCount;
    return mapped;
  }
}
