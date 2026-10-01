import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/pin_coordinates.dart';
import '../domain/pin_display_mode.dart';
import '../domain/pin_type.dart';

const _uuid = Uuid();

final studyPinsForResourceProvider =
    StreamProvider.family<List<StudyPin>, String>((ref, resourceId) {
      final db = ref.watch(databaseProvider);
      return db.watchStudyPinsForResource(resourceId);
    });

final studyPinByIdProvider = StreamProvider.family<StudyPin?, String>((
  ref,
  pinId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchStudyPinById(pinId);
});

final textRangesForResourceProvider =
    StreamProvider.family<List<StudyPinTextRange>, String>((ref, resourceId) {
      final db = ref.watch(databaseProvider);
      return db.watchTextRangesForResource(resourceId);
    });

final textRangesForPinProvider =
    StreamProvider.family<List<StudyPinTextRange>, String>((ref, pinId) {
      final db = ref.watch(databaseProvider);
      return db.watchTextRangesForPin(pinId);
    });

/// Viewer-local Annotate toggle (not persisted).
final addPinModeProvider = StateProvider.autoDispose.family<bool, String>(
  (ref, resourceId) => false,
);

/// Viewer-local display mode (not persisted).
final pinDisplayModeProvider = StateProvider.autoDispose
    .family<PinDisplayMode, String>(
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

class TextRangeInput {
  const TextRangeInput({required this.pageNumber, required this.rect});

  final int pageNumber;
  final NormalizedRect rect;
}

class CreateTextStudyPinInput {
  const CreateTextStudyPinInput({
    required this.resourceId,
    required this.selectedText,
    required this.ranges,
    required this.shortText,
    this.fullExplanation,
  });

  final String resourceId;
  final String selectedText;
  final List<TextRangeInput> ranges;
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
      pinType: Value(StudyPinType.point.dbValue),
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

Future<StudyPin> createTextStudyPin(
  WidgetRef ref,
  CreateTextStudyPinInput input,
) async {
  if (input.ranges.isEmpty) {
    throw ArgumentError('Text Study Pin requires at least one range.');
  }

  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final id = _uuid.v4();
  final shortText = input.shortText.trim();
  final full = input.fullExplanation?.trim();
  final selected = input.selectedText.trim();
  final first = input.ranges.first;
  final anchor = first.rect.center;

  final rangeCompanions = <StudyPinTextRangesCompanion>[
    for (var i = 0; i < input.ranges.length; i++)
      StudyPinTextRangesCompanion.insert(
        id: _uuid.v4(),
        studyPinId: id,
        pageNumber: input.ranges[i].pageNumber,
        xRatio: input.ranges[i].rect.xRatio,
        yRatio: input.ranges[i].rect.yRatio,
        widthRatio: input.ranges[i].rect.widthRatio,
        heightRatio: input.ranges[i].rect.heightRatio,
        sortOrder: Value(i),
      ),
  ];

  await db.insertTextStudyPin(
    pin: StudyPinsCompanion.insert(
      id: id,
      resourceId: input.resourceId,
      pinType: Value(StudyPinType.text.dbValue),
      pageNumber: Value(first.pageNumber),
      xRatio: anchor.xRatio,
      yRatio: anchor.yRatio,
      shortText: shortText,
      fullExplanation: Value(full == null || full.isEmpty ? null : full),
      selectedText: Value(selected.isEmpty ? null : selected),
      createdAt: now,
      updatedAt: now,
    ),
    ranges: rangeCompanions,
  );

  final created = await db.getStudyPinById(id);
  if (created == null) {
    throw StateError('Failed to create text Study Pin.');
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

/// Persists a new point-pin location once after a drag ends.
///
/// Does not change texts, type, selectedText, or page (unless [pageNumber] is
/// passed). Ratios are clamped to 0–1 via [NormalizedPoint].
Future<void> updateStudyPinPosition(
  WidgetRef ref, {
  required StudyPin pin,
  required NormalizedPoint point,
  int? pageNumber,
}) async {
  if (!pin.isPointPin) {
    throw ArgumentError('Only point Study Pins can be repositioned.');
  }

  final db = ref.read(databaseProvider);
  final clamped = NormalizedPoint(
    xRatio: point.xRatio.clamp(0.0, 1.0),
    yRatio: point.yRatio.clamp(0.0, 1.0),
  );

  await db.updateStudyPin(
    pin.copyWith(
      pageNumber: Value(pageNumber ?? pin.pageNumber),
      xRatio: clamped.xRatio,
      yRatio: clamped.yRatio,
      updatedAt: DateTime.now(),
    ),
  );
}

Future<void> deleteStudyPin(WidgetRef ref, {required String pinId}) async {
  final db = ref.read(databaseProvider);
  await db.deleteStudyPin(pinId);
}

extension StudyPinTypeX on StudyPin {
  StudyPinType get type => StudyPinType.fromDb(pinType);

  bool get isPointPin => type == StudyPinType.point;

  bool get isTextPin => type == StudyPinType.text;
}
