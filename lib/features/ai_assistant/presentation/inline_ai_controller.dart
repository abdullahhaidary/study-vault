import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/ai_providers.dart';
import '../data/ai_settings_store.dart';
import '../domain/ai_actions.dart';
import '../domain/ai_exceptions.dart';
import '../domain/ai_models.dart';
import '../domain/ai_provider.dart';
import '../domain/annotation_ai_context.dart';
import '../domain/inline_ai_models.dart';
import '../services/annotation_ai_history_service.dart';

/// Orchestrates inline AI: history, generate, regenerate, follow-up.
///
/// UI must call [AiAssistantController.ensureReady] before [runAction] /
/// [ask] / [regenerate] when a network call is needed.
class InlineAiController extends ChangeNotifier {
  InlineAiController({
    required this.ref,
    required InlineAiSourceMode mode,
    required AnnotationAiContext context,
    this.existingPin,
  }) : _state = InlineAiViewState(
         mode: mode,
         context: context,
         phase: InlineAiPhase.ready,
       );

  final WidgetRef ref;
  StudyPin? existingPin;

  InlineAiViewState _state;
  InlineAiViewState get state => _state;

  AnnotationAiHistoryService get _history =>
      ref.read(annotationAiHistoryServiceProvider);

  bool _disposed = false;
  int _runToken = 0;

  void _set(InlineAiViewState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> bootstrap() async {
    final counts = await _history.getGenerationCounts(
      sourceFingerprint: _state.sourceFingerprint,
    );
    if (_disposed) return;
    _set(_state.copyWith(counts: counts));
  }

  /// Select a quick action. Loads existing history when present; otherwise generates.
  Future<void> runAction(
    AiStudyAction action, {
    String? customPrompt,
    AiSummarizeMode? summarizeMode,
    AiRephraseMode? rephraseMode,
    AiLanguage? translateTarget,
    required Future<bool> Function() ensureReady,
  }) async {
    if (_state.phase == InlineAiPhase.loading) return;

    final gens = await _history.getGenerations(
      sourceFingerprint: _state.sourceFingerprint,
      action: action,
    );
    if (_disposed) return;

    if (gens.isNotEmpty &&
        (customPrompt == null || customPrompt.trim().isEmpty)) {
      _set(
        _state.copyWith(
          action: action,
          generations: gens,
          selected: gens.last,
          phase: InlineAiPhase.success,
          clearError: true,
          summarizeMode: summarizeMode,
          rephraseMode: rephraseMode,
          translateTarget: translateTarget,
          customPrompt: customPrompt,
          focusAskField: false,
        ),
      );
      return;
    }

    await _generate(
      action: action,
      customPrompt: customPrompt,
      summarizeMode: summarizeMode,
      rephraseMode: rephraseMode,
      translateTarget: translateTarget,
      ensureReady: ensureReady,
    );
  }

  Future<void> ask(
    String prompt, {
    required Future<bool> Function() ensureReady,
  }) async {
    final question = prompt.trim();
    if (question.isEmpty) return;

    final current = _state.action;
    if (current != null && _state.hasResponse) {
      await regenerate(ensureReady: ensureReady, instruction: question);
      return;
    }

    await runAction(
      AiStudyAction.askAi,
      customPrompt: question,
      ensureReady: ensureReady,
    );
  }

  Future<void> regenerate({
    required Future<bool> Function() ensureReady,
    String? instruction,
  }) async {
    final action = _state.action;
    if (action == null || _state.phase == InlineAiPhase.loading) return;

    final token = ++_runToken;
    final previous = _state.generations;
    final previousSelected = _state.selected;

    _set(_state.copyWith(phase: InlineAiPhase.loading, clearError: true));

    try {
      if (!await ensureReady()) {
        if (token != _runToken || _disposed) return;
        _set(
          _state.copyWith(
            phase: previous.isEmpty
                ? InlineAiPhase.ready
                : InlineAiPhase.success,
            generations: previous,
            selected: previousSelected,
          ),
        );
        return;
      }
      if (token != _runToken || _disposed) return;

      final settings = ref.read(aiSettingsStoreProvider);
      final provider = await settings.getProvider();
      final storedModel = await settings.getModelIdFor(provider);
      final modelName = resolveActiveModelId(
        provider: provider,
        storedModelId: storedModel,
        action: action,
      );
      final saved = await _history.regenerate(
        context: _state.context,
        action: action,
        parent: _state.selected,
        rephraseMode: _state.rephraseMode,
        organizeMode: null,
        summarizeMode: _state.summarizeMode,
        translateTarget: _state.translateTarget,
        customPrompt: _state.customPrompt,
        regenerateInstruction: instruction,
        modelName: modelName,
        provider: provider.storageValue,
        sendMode: _state.pageSendMode,
      );

      if (token != _runToken || _disposed) return;

      final gens = [...previous, saved];
      final counts = Map<AiStudyAction, int>.from(_state.counts);
      counts[action] = gens.length;

      _set(
        _state.copyWith(
          phase: InlineAiPhase.success,
          generations: gens,
          selected: saved,
          counts: counts,
          clearError: true,
        ),
      );
      ref.invalidate(
        annotationAiGenerationCountsProvider(_state.sourceFingerprint),
      );
    } on AiException catch (e) {
      if (token != _runToken || _disposed) return;
      _set(
        _state.copyWith(
          phase: previous.isEmpty ? InlineAiPhase.error : InlineAiPhase.success,
          generations: previous,
          selected: previousSelected,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      if (token != _runToken || _disposed) return;
      _set(
        _state.copyWith(
          phase: previous.isEmpty ? InlineAiPhase.error : InlineAiPhase.success,
          generations: previous,
          selected: previousSelected,
          errorMessage: 'Couldn’t generate a response.',
        ),
      );
    }
  }

  Future<void> _generate({
    required AiStudyAction action,
    String? customPrompt,
    AiSummarizeMode? summarizeMode,
    AiRephraseMode? rephraseMode,
    AiLanguage? translateTarget,
    required Future<bool> Function() ensureReady,
  }) async {
    final token = ++_runToken;
    final priorForAction = await _history.getGenerations(
      sourceFingerprint: _state.sourceFingerprint,
      action: action,
    );
    if (_disposed || token != _runToken) return;

    _set(
      _state.copyWith(
        action: action,
        phase: InlineAiPhase.loading,
        generations: priorForAction,
        selected: priorForAction.isNotEmpty ? priorForAction.last : null,
        clearError: true,
        clearSelected: priorForAction.isEmpty,
        summarizeMode: summarizeMode,
        rephraseMode: rephraseMode,
        translateTarget: translateTarget,
        customPrompt: customPrompt,
        focusAskField: false,
      ),
    );

    if (!_state.context.hasUsableText &&
        _state.pageSendMode != AiPageSendMode.image) {
      _set(
        _state.copyWith(
          phase: InlineAiPhase.error,
          errorMessage: _state.mode == InlineAiSourceMode.page
              ? 'This page has no extractable text. Send as Image instead.'
              : 'Select text for AI first.',
        ),
      );
      return;
    }

    final sourceLen =
        _state.context.primaryText.length +
        (_state.context.surroundingText?.length ?? 0);
    if (_state.pageSendMode != AiPageSendMode.image &&
        sourceLen > kAiHardSourceLimit) {
      _set(
        _state.copyWith(
          phase: InlineAiPhase.error,
          errorMessage:
              'This source is too large for AI. Select a shorter passage.',
        ),
      );
      return;
    }

    try {
      if (!await ensureReady()) {
        if (token != _runToken || _disposed) return;
        _set(
          _state.copyWith(
            phase: priorForAction.isEmpty
                ? InlineAiPhase.ready
                : InlineAiPhase.success,
            generations: priorForAction,
            selected: priorForAction.isNotEmpty ? priorForAction.last : null,
            clearAction: priorForAction.isEmpty,
            clearSelected: priorForAction.isEmpty,
          ),
        );
        return;
      }
      if (token != _runToken || _disposed) return;

      final settings = ref.read(aiSettingsStoreProvider);
      final provider = await settings.getProvider();
      final storedModel = await settings.getModelIdFor(provider);
      final modelName = resolveActiveModelId(
        provider: provider,
        storedModelId: storedModel,
        action: action,
      );
      final saved = await _history.generate(
        context: _state.context,
        action: action,
        summarizeMode: summarizeMode,
        rephraseMode: rephraseMode,
        translateTarget: translateTarget,
        customPrompt: customPrompt,
        modelName: modelName,
        provider: provider.storageValue,
        useCache: action.isCacheable,
        sendMode: _state.pageSendMode,
      );

      if (token != _runToken || _disposed) return;

      final all = await _history.getGenerations(
        sourceFingerprint: _state.sourceFingerprint,
        action: action,
      );
      if (token != _runToken || _disposed) return;

      final counts = Map<AiStudyAction, int>.from(_state.counts);
      counts[action] = all.length;

      _set(
        _state.copyWith(
          phase: InlineAiPhase.success,
          generations: all.isEmpty ? [...priorForAction, saved] : all,
          selected: all.isNotEmpty ? all.last : saved,
          counts: counts,
          clearError: true,
        ),
      );
      ref.invalidate(
        annotationAiGenerationCountsProvider(_state.sourceFingerprint),
      );
    } on AiException catch (e) {
      if (token != _runToken || _disposed) return;
      _set(
        _state.copyWith(
          phase: priorForAction.isEmpty
              ? InlineAiPhase.error
              : InlineAiPhase.success,
          errorMessage: e.message,
          generations: priorForAction,
          selected: priorForAction.isNotEmpty ? priorForAction.last : null,
        ),
      );
    } catch (_) {
      if (token != _runToken || _disposed) return;
      _set(
        _state.copyWith(
          phase: priorForAction.isEmpty
              ? InlineAiPhase.error
              : InlineAiPhase.success,
          errorMessage: 'Couldn’t generate a response.',
          generations: priorForAction,
          selected: priorForAction.isNotEmpty ? priorForAction.last : null,
        ),
      );
    }
  }

  void selectGeneration(AnnotationAiGeneration generation) {
    _set(
      _state.copyWith(
        selected: generation,
        phase: InlineAiPhase.success,
        clearError: true,
      ),
    );
  }

  Future<void> deleteSelected() async {
    final current = _state.selected;
    final action = _state.action;
    if (current == null || action == null) return;

    await _history.deleteGeneration(current.id);
    final remaining = _state.generations
        .where((g) => g.id != current.id)
        .toList();
    AnnotationAiGeneration? next;
    if (remaining.isNotEmpty) {
      final lower = remaining
          .where((g) => g.generationNumber < current.generationNumber)
          .toList();
      next = lower.isNotEmpty ? lower.last : remaining.first;
    }

    final counts = Map<AiStudyAction, int>.from(_state.counts);
    counts[action] = remaining.length;

    _set(
      _state.copyWith(
        generations: remaining,
        selected: next,
        phase: remaining.isEmpty ? InlineAiPhase.ready : InlineAiPhase.success,
        clearSelected: remaining.isEmpty,
        clearAction: remaining.isEmpty,
        clearError: true,
        counts: counts,
      ),
    );
    ref.invalidate(
      annotationAiGenerationCountsProvider(_state.sourceFingerprint),
    );
  }

  void clearErrorAndReady() {
    _set(
      _state.copyWith(
        phase: _state.hasResponse ? InlineAiPhase.success : InlineAiPhase.ready,
        clearError: true,
      ),
    );
  }

  void setPageSendMode(AiPageSendMode mode) {
    if (_state.mode != InlineAiSourceMode.page) return;
    if (_state.pageSendMode == mode) return;
    _set(_state.copyWith(pageSendMode: mode));
  }

  void requestAskFocus() {
    _set(_state.copyWith(focusAskField: true));
  }

  void bindExistingPin(StudyPin pin) {
    existingPin = pin;
    final updated = AnnotationAiContext(
      selectedText: _state.context.selectedText,
      materialId: _state.context.materialId,
      lessonId: _state.context.lessonId,
      pageNumber: _state.context.pageNumber,
      annotationText: _state.context.annotationText,
      surroundingText: _state.context.surroundingText,
      annotationId: pin.id,
      shortDescription: pin.shortText,
      language: _state.context.language,
      direction: _state.context.direction,
      filePath: _state.context.filePath,
    );
    _set(_state.copyWith(context: updated));
  }

  AiStudyRequest buildStudyRequest() {
    final action = _state.action ?? AiStudyAction.explain;
    return _state.context.toStudyRequest(
      action: action,
      summarizeMode: _state.summarizeMode,
      rephraseMode: _state.rephraseMode,
      translateTarget: _state.translateTarget,
      customPrompt: _state.customPrompt ?? _state.selected?.customPrompt,
      pageSendMode: _state.pageSendMode,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _runToken++;
    super.dispose();
  }
}
