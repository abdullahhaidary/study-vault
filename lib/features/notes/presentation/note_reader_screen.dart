import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/scroll_edge_arrows.dart';
import '../../ai_chat/domain/ai_chat_models.dart';
import '../../ai_chat/presentation/widgets/ai_discussions_section.dart';
import '../../favorites/presentation/favorite_star_button.dart';
import '../../study_pins/presentation/widgets/study_rich_text_viewer.dart';
import '../data/notes_providers.dart';

class NoteReaderScreen extends ConsumerWidget {
  const NoteReaderScreen({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(studyNoteByIdProvider(noteId));
    return note.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text('Could not load note: $error'))),
      data: (item) {
        if (item == null) {
          return const Scaffold(body: Center(child: Text('Note not found.')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(item.title),
            actions: [
              FavoriteStarButton(entityType: 'note', entityId: item.id),
              IconButton(
                tooltip: 'Edit note',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed(AppRoutes.noteEditor, arguments: item.id),
              ),
            ],
          ),
          body: ScrollEdgeArrows(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                StudyRichTextViewer(storedValue: item.content),
                const SizedBox(height: 20),
                AiDiscussionsSection(kind: AiContextKind.note, id: item.id),
              ],
            ),
          ),
        );
      },
    );
  }
}
