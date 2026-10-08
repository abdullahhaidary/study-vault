import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/auto_direction_text.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
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

  Future<void> _deleteNote(
    BuildContext context,
    WidgetRef ref,
    String noteId,
    String title,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete note?',
      message: '"$title" will be permanently deleted.',
    );
    if (confirmed) await deleteStudyNote(ref, noteId: noteId);
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
                trailing: PopupMenuButton<String>(
                  tooltip: 'Note options',
                  onSelected: (value) {
                    if (value == 'open') {
                      Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.noteReader, arguments: note.id);
                    } else if (value == 'edit') {
                      Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.noteEditor, arguments: note.id);
                    } else if (value == 'delete') {
                      _deleteNote(context, ref, note.id, note.title);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'open', child: Text('Open')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
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
