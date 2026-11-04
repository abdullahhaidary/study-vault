enum StudySearchScopeKind { library, class_, subject, lesson }

/// A library subtree. IDs constrain SQL before result limits are applied.
class StudySearchScope {
  const StudySearchScope.library()
    : kind = StudySearchScopeKind.library,
      id = null,
      title = 'Entire library';
  const StudySearchScope.class_({required this.id, required this.title})
    : kind = StudySearchScopeKind.class_;
  const StudySearchScope.subject({required this.id, required this.title})
    : kind = StudySearchScopeKind.subject;
  const StudySearchScope.lesson({required this.id, required this.title})
    : kind = StudySearchScopeKind.lesson;
  final StudySearchScopeKind kind;
  final String? id;
  final String title;

  /// Column expressions come exclusively from application SQL, never input.
  String predicate({String? classId, String? subjectId, String? lessonId}) {
    final column = switch (kind) {
      StudySearchScopeKind.library => null,
      StudySearchScopeKind.class_ => classId,
      StudySearchScopeKind.subject => subjectId,
      StudySearchScopeKind.lesson => lessonId,
    };
    if (kind == StudySearchScopeKind.library) return '1';
    return column == null ? '0' : '$column = ?';
  }

  bool binds({String? classId, String? subjectId, String? lessonId}) =>
      switch (kind) {
        StudySearchScopeKind.library => false,
        StudySearchScopeKind.class_ => classId != null,
        StudySearchScopeKind.subject => subjectId != null,
        StudySearchScopeKind.lesson => lessonId != null,
      };
}
