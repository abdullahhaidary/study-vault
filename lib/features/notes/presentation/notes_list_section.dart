import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../data/notes_providers.dart';

/// Reusable compact note list for subject and lesson detail screens.
class NotesListSection extends ConsumerWidget {
  const NotesListSection.subject({super.key, required this.subjectId})
    : lessonId = null;

  const NotesListSection.lesson({super.key, required this.lessonId})
    : subjectId = null;

  final String? subjectId;
  final String? lessonId;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final note = await createStudyNote(
      ref,
      subjectId: subjectId,
      lessonId: lessonId,
      title: 'Untitled note',
    );
    if (context.mounted) {
      await Navigator.of(
        context,
      ).pushNamed(AppRoutes.noteEditor, arguments: note.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = subjectId != null
        ? ref.watch(notesForSubjectProvider(subjectId!))
        : ref.watch(notesForLessonProvider(lessonId!));
    final theme = Theme.of(context);
    return notes.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text('Could not load notes: $error'),
      data: (items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Notes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('New Note'),
              ),
            ],
          ),
          if (items.isEmpty)
            Text(
              'No notes yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...items.map(
              (note) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.sticky_note_2_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: AutoDirectionText(note.title),
                subtitle:
                    note.plainTextContent == null ||
                        note.plainTextContent!.isEmpty
                    ? null
                    : AutoDirectionText(
                        note.plainTextContent!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.outline,
                ),
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(AppRoutes.noteReader, arguments: note.id),
              ),
            ),
        ],
      ),
    );
  }
}
