import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../ai_assistant/data/ai_credential_store.dart';
import '../../ai_assistant/domain/ai_provider.dart';
import '../data/book_repository.dart';
import '../domain/book_text_index.dart';

/// Gemini text embeddings for optional semantic ("smart") search.
abstract interface class BookEmbeddingClient {
  String get model;
  Future<bool> get isAvailable;
  Future<List<List<double>>> embed(List<String> texts, {required bool query});
}

class GeminiBookEmbeddingClient implements BookEmbeddingClient {
  GeminiBookEmbeddingClient(
    this._credentials, {
    http.Client? httpClient,
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  }) : _http = httpClient ?? http.Client();

  final AiCredentialStore _credentials;
  final http.Client _http;
  final String baseUrl;

  @override
  String get model => 'gemini-embedding-001@768';

  static const _modelId = 'gemini-embedding-001';
  static const batch = 100;
  static const maxChars = 7000;

  @override
  Future<bool> get isAvailable async =>
      ((await _credentials.readApiKeyFor(AiProviderId.gemini)) ?? '')
          .trim()
          .isNotEmpty;

  @override
  Future<List<List<double>>> embed(
    List<String> texts, {
    required bool query,
  }) async {
    final key = (await _credentials.readApiKeyFor(AiProviderId.gemini))?.trim();
    if (key == null || key.isEmpty) {
      throw StateError('Add a Gemini API key in Settings to use smart search.');
    }
    final result = <List<double>>[];
    for (var i = 0; i < texts.length; i += batch) {
      final slice = texts.sublist(
        i,
        i + batch > texts.length ? texts.length : i + batch,
      );
      final http.Response response;
      try {
        response = await _http
            .post(
              Uri.parse('$baseUrl/models/$_modelId:batchEmbedContents'),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': key,
              },
              body: jsonEncode({
                'requests': [
                  for (final text in slice)
                    {
                      'model': 'models/$_modelId',
                      'content': {
                        'parts': [
                          {
                            'text': text.length > maxChars
                                ? text.substring(0, maxChars)
                                : (text.trim().isEmpty ? '(empty page)' : text),
                          },
                        ],
                      },
                      'taskType': query
                          ? 'RETRIEVAL_QUERY'
                          : 'RETRIEVAL_DOCUMENT',
                      'outputDimensionality': 768,
                    },
                ],
              }),
            )
            .timeout(const Duration(seconds: 90));
      } on SocketException {
        throw StateError('No internet connection for smart search.');
      } on TimeoutException {
        throw StateError('Gemini embeddings timed out. Try again.');
      }
      if (response.statusCode != 200) {
        throw StateError(
          'Gemini embeddings failed (${response.statusCode}). '
          'Check your Gemini key and quota.',
        );
      }
      final embeddings =
          (jsonDecode(response.body) as Map<String, dynamic>)['embeddings']
              as List;
      for (final e in embeddings) {
        result.add([
          for (final v in (e as Map)['values'] as List) (v as num).toDouble(),
        ]);
      }
    }
    return result;
  }
}

/// Keyword ranking always; semantic ranking fused in when a page vector
/// index exists for the book.
class BookSearchService {
  BookSearchService(this._repository, this._embeddings);

  final BookRepository _repository;
  final BookEmbeddingClient _embeddings;
  final _cache = <String, ({int pages, BookTextIndex index})>{};

  BookEmbeddingClient get embeddings => _embeddings;

  Future<BookTextIndex> index(String bookId) async {
    final state = await _repository.localState(bookId);
    final cached = _cache[bookId];
    if (cached != null && cached.pages == state.indexedPages) {
      return cached.index;
    }
    final index = BookTextIndex.build(await _repository.pages(bookId));
    _cache[bookId] = (pages: state.indexedPages, index: index);
    return index;
  }

  void invalidate(String bookId) => _cache.remove(bookId);

  Future<List<BookSearchHit>> search(
    String bookId,
    String query, {
    int limit = 20,
    ({int start, int end})? within,
  }) async {
    final textIndex = await index(bookId);
    final keyword = textIndex.search(query, limit: 50, within: within);
    final state = await _repository.localState(bookId);
    if (state.vectorsModel != _embeddings.model) {
      return keyword.take(limit).toList();
    }
    final vectors = await _repository.vectors(bookId, _embeddings.model);
    final List<double> queryVector;
    try {
      queryVector = (await _embeddings.embed([query], query: true)).single;
    } on Object {
      return keyword.take(limit).toList();
    }
    final semantic = [
      for (final e in vectors.entries)
        if (within == null || (e.key >= within.start && e.key <= within.end))
          (page: e.key, score: cosine(queryVector, e.value)),
    ]..sort((a, b) => b.score.compareTo(a.score));
    final fused = fuseRankings([
      [for (final h in keyword) h.page],
      [for (final s in semantic.take(50)) s.page],
    ], limit: limit);
    final terms = BookTextIndex.tokenize(query).toSet();
    final byPage = {for (final h in keyword) h.page: h};
    return [
      for (final page in fused)
        byPage[page] ??
            BookSearchHit(
              page: page,
              score: 0,
              snippet: BookTextIndex.snippet(
                textIndex.textOf(page) ?? '',
                terms,
              ),
            ),
    ];
  }

  /// Embeds every indexed page; resumable.
  Future<void> buildVectors(
    String bookId, {
    void Function(int done, int total)? onProgress,
  }) async {
    final pages = await _repository.pages(bookId);
    final have = await _repository.vectorPages(bookId, _embeddings.model);
    final missing = [
      for (final page in pages)
        if (!have.contains(page.page)) page,
    ];
    var done = pages.length - missing.length;
    onProgress?.call(done, pages.length);
    for (var i = 0; i < missing.length; i += GeminiBookEmbeddingClient.batch) {
      final slice = missing.sublist(
        i,
        i + GeminiBookEmbeddingClient.batch > missing.length
            ? missing.length
            : i + GeminiBookEmbeddingClient.batch,
      );
      final vectors = await _embeddings.embed([
        for (final page in slice) page.text,
      ], query: false);
      await _repository.saveVectors(bookId, _embeddings.model, {
        for (var j = 0; j < slice.length; j++) slice[j].page: vectors[j],
      });
      done += slice.length;
      onProgress?.call(done, pages.length);
    }
    await _repository.finishVectors(bookId, _embeddings.model);
  }
}
