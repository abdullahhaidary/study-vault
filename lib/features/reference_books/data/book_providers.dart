import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../ai_assistant/data/ai_providers.dart';
import '../../ai_questions/data/quiz_providers.dart';
import '../../pdf_ai_materials/data/pdf_ai_material_providers.dart';
import '../services/book_ai_service.dart';
import '../services/book_import_service.dart';
import '../services/book_search_service.dart';
import 'book_repository.dart';

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => BookRepository(ref.watch(databaseProvider)),
);

final bookImportServiceProvider = Provider<BookImportService>(
  (ref) => BookImportService(ref.watch(bookRepositoryProvider)),
);

final bookSearchServiceProvider = Provider<BookSearchService>(
  (ref) => BookSearchService(
    ref.watch(bookRepositoryProvider),
    GeminiBookEmbeddingClient(ref.watch(aiCredentialStoreProvider)),
  ),
);

final bookAiServiceProvider = Provider<BookAiService>(
  (ref) => BookAiService(
    ref.watch(bookRepositoryProvider),
    ref.watch(bookSearchServiceProvider),
    ref.watch(pdfAiCompletionClientProvider),
    quizzes: ref.watch(quizGenerationServiceProvider),
  ),
);

final booksProvider = StreamProvider<List<ReferenceBook>>(
  (ref) => ref.watch(bookRepositoryProvider).watchBooks(),
);

final bookProvider = StreamProvider.family<ReferenceBook?, String>(
  (ref, id) => ref.watch(bookRepositoryProvider).watchBook(id),
);

final booksForSubjectProvider =
    StreamProvider.family<List<ReferenceBook>, String>(
      (ref, subjectId) =>
          ref.watch(bookRepositoryProvider).watchBooksForSubject(subjectId),
    );

final bookSubjectsProvider = StreamProvider.family<List<Subject>, String>(
  (ref, bookId) =>
      ref.watch(bookRepositoryProvider).watchSubjectsForBook(bookId),
);

final bookChaptersProvider =
    StreamProvider.family<List<ReferenceBookChapter>, String>(
      (ref, bookId) => ref.watch(bookRepositoryProvider).watchChapters(bookId),
    );

final bookAiItemsProvider =
    StreamProvider.family<List<ReferenceBookAiItem>, String>(
      (ref, bookId) => ref.watch(bookRepositoryProvider).watchAiItems(bookId),
    );

final bookNotesProvider =
    StreamProvider.family<List<ReferenceBookNote>, String>(
      (ref, bookId) => ref.watch(bookRepositoryProvider).watchNotes(bookId),
    );

final bookMessagesProvider =
    StreamProvider.family<List<ReferenceBookMessage>, String>(
      (ref, bookId) => ref.watch(bookRepositoryProvider).watchMessages(bookId),
    );

final bookLinksProvider =
    StreamProvider.family<List<ReferenceBookLink>, String>(
      (ref, bookId) => ref.watch(bookRepositoryProvider).watchLinks(bookId),
    );

final materialBookLinksProvider =
    StreamProvider.family<List<(ReferenceBookLink, ReferenceBook)>, String>(
      (ref, materialId) =>
          ref.watch(bookRepositoryProvider).watchLinksForMaterial(materialId),
    );

final bookLocalStateProvider = StreamProvider.family<BookLocalState, String>(
  (ref, bookId) => ref.watch(bookRepositoryProvider).watchLocalState(bookId),
);

final chapterQuizzesProvider = StreamProvider.family<List<QuestionSet>, String>(
  (ref, chapterId) =>
      ref.watch(bookRepositoryProvider).watchChapterQuizzes(chapterId),
);
