import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../domain/roadmap_models.dart';
import 'class_roadmap_repository.dart';

final classRoadmapRepositoryProvider = Provider<ClassRoadmapRepository>((ref) {
  return ClassRoadmapRepository(ref.watch(databaseProvider));
});

final classRoadmapProvider =
    StreamProvider.family<List<RoadmapStep>, String>((ref, classId) {
      return ref.watch(classRoadmapRepositoryProvider).watchSteps(classId);
    });
