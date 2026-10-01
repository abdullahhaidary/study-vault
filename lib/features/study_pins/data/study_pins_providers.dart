import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/pin_coordinates.dart';
import '../domain/pin_display_mode.dart';

const _uuid = Uuid();

final studyPinsForResourceProvider =
    StreamProvider.family<List<StudyPin>, String>((ref, resourceId) {
  final db = ref.watch(databaseProvider);
  return db.watchStudyPinsForResource(resourceId);
});

final studyPinByIdProvider =
    StreamProvider.family<StudyPin?, String>((ref, pinId) {
  final db = ref.watch(databaseProvider);
  return db.watchStudyPinById(pinId);
});

/// Viewer-local Add Pin toggle (not persisted).
final addPinModeProvider =
    StateProvider.autoDispose.family<bool, String>((ref, resourceId) => false);

/// Viewer-local display mode (not persisted).
final pinDisplayModeProvider =
    StateProvider.autoDispose.family<PinDisplayMode, String>(
  (ref, resourceId) => PinDisplayMode.dotsAndText,
);

class CreateStudyPinInput {
  const CreateStudyPinInput({
    required this.resourceId,
    required this.point,
    required this.shortText,
    this.pageNumber,
    this.fullExplanation,
  });

  final String resourceId;
  final NormalizedPoint point;
  final int? pageNumber;
  final String shortText;
  final String? fullExplanation;
}

Future<StudyPin> createStudyPin(
  WidgetRef ref,
  CreateStudyPinInput input,
) async {
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final id = _uuid.v4();
  final shortText = input.shortText.trim();
  final full = input.fullExplanation?.trim();

  await db.insertStudyPin(
    StudyPinsCompanion.insert(
      id: id,
      resourceId: input.resourceId,
      pageNumber: Value(input.pageNumber),
      xRatio: input.point.xRatio,
      yRatio: input.point.yRatio,
      shortText: shortText,
      fullExplanation: Value(full == null || full.isEmpty ? null : full),
      createdAt: now,
      updatedAt: now,
    ),
  );

  final created = await db.getStudyPinById(id);
  if (created == null) {
    throw StateError('Failed to create Study Pin.');
  }
  return created;
}

Future<void> updateStudyPinTexts(
  WidgetRef ref, {
  required StudyPin pin,
  required String shortText,
  String? fullExplanation,
}) async {
  final db = ref.read(databaseProvider);
  final trimmedShort = shortText.trim();
  final trimmedFull = fullExplanation?.trim();

  await db.updateStudyPin(
    pin.copyWith(
      shortText: trimmedShort,
      fullExplanation: Value(
        trimmedFull == null || trimmedFull.isEmpty ? null : trimmedFull,
      ),
      updatedAt: DateTime.now(),
    ),
  );
}

Future<void> deleteStudyPin(WidgetRef ref, {required String pinId}) async {
  final db = ref.read(databaseProvider);
  await db.deleteStudyPin(pinId);
}
