import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../pdf_ai_materials/data/pdf_ai_material_providers.dart';
import '../domain/course_review_models.dart';
import '../services/course_review_service.dart';

final courseReviewServiceProvider = Provider<CourseReviewService>((ref) {
  return CourseReviewService(
    ref.watch(databaseProvider),
    ref.watch(pdfAiCompletionClientProvider),
    ref.watch(pdfAiMaterialServiceProvider),
  );
});

final courseReviewProvider = StreamProvider.family<CourseReviewState?, String>((
  ref,
  subjectId,
) {
  return ref.watch(courseReviewServiceProvider).repository.watch(subjectId);
});
