import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/ai_models.dart';
import '../domain/failed_ai_request.dart';
export '../domain/failed_ai_request.dart';

class FailedAiRequestsNotifier extends StateNotifier<List<FailedAiRequest>> {
  FailedAiRequestsNotifier() : super(const []);

  void add({
    required AiStudyRequest request,
    String? errorMessage,
    bool wasCancelled = false,
  }) {
    state = [
      FailedAiRequest(
        id: const Uuid().v4(),
        failedAt: DateTime.now(),
        request: request,
        errorMessage: errorMessage,
        wasCancelled: wasCancelled,
      ),
      ...state,
    ];
  }

  void remove(String id) {
    state = state.where((r) => r.id != id).toList();
  }

  void clear() {
    state = const [];
  }
}

final failedAiRequestsProvider =
    StateNotifierProvider<FailedAiRequestsNotifier, List<FailedAiRequest>>(
  (ref) => FailedAiRequestsNotifier(),
);
