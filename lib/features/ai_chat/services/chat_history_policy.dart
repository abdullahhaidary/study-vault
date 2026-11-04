import '../../ai_assistant/domain/ai_exceptions.dart';
import '../domain/ai_chat_models.dart';

/// Deterministic, batched compaction. Replaying persisted history produces the
/// same checkpoint until the next high-water mark, including after a restart.
/// Excerpts are explicitly labeled incomplete; they never invent a summary.
abstract final class ChatHistoryPolicy {
  static int estimateTokens(String text) {
    var quarters = 0;
    for (final rune in text.runes) {
      quarters += rune < 128 ? 1 : 4;
    }
    return (quarters + 3) ~/ 4 + 8;
  }

  static bool hasDocument(AiChatTurn turn) =>
      turn.pinForCache ||
      turn.content.contains('Attached Study Vault context:') ||
      turn.content.contains('SOURCE MATERIAL:') ||
      turn.content.contains('SELECTED TEXT:');

  static List<AiChatTurn> compact(
    List<AiChatTurn> history, {
    int maxTokens = 24000,
    int maxMessages = 40,
  }) {
    if (history.isEmpty) return history;
    final firstUser = history.indexWhere((t) => t.role == AiChatRole.user);
    if (firstUser < 0) return history;
    final prefix = history.take(firstUser + 1).toList();
    final recent = <AiChatTurn>[];
    final archived = <AiChatTurn>[];
    AiChatTurn? memory;
    List<AiChatTurn> outgoing() => [...prefix, ?memory, ...recent];
    int tokens(Iterable<AiChatTurn> turns) =>
        turns.fold(0, (n, t) => n + estimateTokens(t.content));
    bool exceeds(int tokenLimit, int messageLimit) =>
        tokens(outgoing()) > tokenLimit || outgoing().length > messageLimit;

    for (final turn in history.skip(firstUser + 1)) {
      recent.add(turn);
      if (turn.role != AiChatRole.user || !exceeds(maxTokens, maxMessages)) {
        continue;
      }
      // Retain a substantial amount of headroom: subsequent requests append
      // unchanged turns rather than moving a sliding window on every send.
      do {
        if (recent.length <= 1) break;
        archived.add(recent.removeAt(0));
        if (archived.last.role == AiChatRole.user &&
            recent.length > 1 &&
            recent.first.role == AiChatRole.assistant) {
          archived.add(recent.removeAt(0));
        }
        memory = AiChatTurn(
          role: AiChatRole.user,
          content: _memory(archived, (maxTokens ~/ 8).clamp(64, 2000)),
        );
      } while (exceeds((maxTokens * .65).floor(), (maxMessages * .65).floor()));
      if (exceeds(maxTokens, maxMessages)) {
        throw const AiServerException(
          'The source material and latest message exceed this chat’s context budget. Start a new chat with a smaller source or question.',
        );
      }
    }
    // Never silently drop a large source or the current question.
    if (tokens(outgoing()) > maxTokens) {
      throw const AiServerException(
        'The source material exceeds this chat’s context budget. Select a smaller source.',
      );
    }
    return outgoing();
  }

  static String _memory(List<AiChatTurn> archived, int budget) {
    final documents = [
      for (final turn in archived)
        if (hasDocument(turn)) turn,
    ];
    final conversation = [
      for (final turn in archived)
        if (!hasDocument(turn)) turn,
    ];
    final buffer = StringBuffer(
      'EARLIER CONVERSATION EXCERPTS\n'
      'These are incomplete verbatim excerpts, not a complete transcript. '
      'Do not infer missing details. The original source remains authoritative.\n',
    );
    for (final turn in documents) {
      buffer.writeln('${turn.role}:\n${turn.content}');
    }
    // Preserve the oldest goal and the most recent archived exchanges.
    final selected = conversation.length <= 9
        ? conversation
        : [conversation.first, ...conversation.skip(conversation.length - 8)];
    final perTurn = (budget ~/ (selected.isEmpty ? 1 : selected.length)).clamp(
      16,
      256,
    );
    for (final turn in selected) {
      var excerpt = turn.content;
      if (estimateTokens(excerpt) > perTurn) {
        final chars = excerpt.runes.take(perTurn - 8).toList();
        excerpt = '${String.fromCharCodes(chars)} […]';
      }
      buffer.writeln('${turn.role}: $excerpt');
    }
    return buffer.toString();
  }
}
