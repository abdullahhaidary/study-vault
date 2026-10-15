import '../../lessons/domain/lesson_progress.dart';

/// One step on a class syllabus / teacher roadmap.
class RoadmapStep {
  const RoadmapStep({
    required this.id,
    required this.classId,
    required this.lessonId,
    required this.lessonName,
    required this.subjectId,
    required this.subjectName,
    required this.progress,
    required this.sortOrder,
    this.note,
  });

  final String id;
  final String classId;
  final String lessonId;
  final String lessonName;
  final String subjectId;
  final String subjectName;
  final LessonProgressStatus progress;
  final int sortOrder;
  final String? note;

  bool get isDone =>
      progress == LessonProgressStatus.reviewed ||
      progress == LessonProgressStatus.mastered;
}

/// A lesson that can still be added to the roadmap.
class RoadmapCandidate {
  const RoadmapCandidate({
    required this.lessonId,
    required this.lessonName,
    required this.subjectId,
    required this.subjectName,
  });

  final String lessonId;
  final String lessonName;
  final String subjectId;
  final String subjectName;
}
