import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import '../../../core/database/app_database.dart';
import '../domain/study_search_scope.dart';

Future<StudySearchScope?> showSearchScopePicker(
  BuildContext context,
  AppDatabase db,
) => showDialog<StudySearchScope>(
  context: context,
  builder: (_) => _ScopeDialog(db: db),
);

class _ScopeDialog extends StatefulWidget {
  const _ScopeDialog({required this.db});
  final AppDatabase db;
  @override
  State<_ScopeDialog> createState() => _ScopeDialogState();
}

class _ScopeDialogState extends State<_ScopeDialog> {
  late Future<List<StudyClass>> _classes;
  Future<List<Subject>>? _subjects;
  Future<List<Lesson>>? _lessons;
  StudyClass? _class;
  Subject? _subject;
  Lesson? _lesson;
  @override
  void initState() {
    super.initState();
    _classes = (widget.db.select(
      widget.db.classes,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Search within'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder(
              future: _classes,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Could not load classes.');
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                return DropdownButtonFormField<StudyClass>(
                  isExpanded: true,
                  initialValue: _class,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: [
                    for (final item in snapshot.data!)
                      DropdownMenuItem(
                        value: item,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _class = value;
                    _subject = null;
                    _lesson = null;
                    _lessons = null;
                    _subjects = value == null
                        ? null
                        : (widget.db.select(widget.db.subjects)
                                ..where((t) => t.classId.equals(value.id))
                                ..orderBy([(t) => OrderingTerm.asc(t.name)]))
                              .get();
                  }),
                );
              },
            ),
            if (_subjects != null)
              FutureBuilder(
                future: _subjects,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Could not load subjects.');
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  return DropdownButtonFormField<Subject>(
                    key: ValueKey(_class?.id),
                    isExpanded: true,
                    initialValue: _subject,
                    decoration: const InputDecoration(
                      labelText: 'Subject (optional)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All subjects'),
                      ),
                      for (final item in snapshot.data!)
                        DropdownMenuItem(
                          value: item,
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _subject = value;
                      _lesson = null;
                      _lessons = value == null
                          ? null
                          : (widget.db.select(widget.db.lessons)
                                  ..where((t) => t.subjectId.equals(value.id))
                                  ..orderBy([(t) => OrderingTerm.asc(t.name)]))
                                .get();
                    }),
                  );
                },
              ),
            if (_lessons != null)
              FutureBuilder(
                future: _lessons,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Could not load lessons.');
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  return DropdownButtonFormField<Lesson>(
                    key: ValueKey(_subject?.id),
                    isExpanded: true,
                    initialValue: _lesson,
                    decoration: const InputDecoration(
                      labelText: 'Lesson (optional)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All lessons'),
                      ),
                      for (final item in snapshot.data!)
                        DropdownMenuItem(
                          value: item,
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _lesson = value),
                  );
                },
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () =>
            Navigator.pop(context, const StudySearchScope.library()),
        child: const Text('Entire library'),
      ),
      FilledButton(
        onPressed: _class == null
            ? null
            : () => Navigator.pop(
                context,
                _lesson != null
                    ? StudySearchScope.lesson(
                        id: _lesson!.id,
                        title: _lesson!.name,
                      )
                    : _subject != null
                    ? StudySearchScope.subject(
                        id: _subject!.id,
                        title: _subject!.name,
                      )
                    : StudySearchScope.class_(
                        id: _class!.id,
                        title: _class!.name,
                      ),
              ),
        child: const Text('Search here'),
      ),
    ],
  );
}
