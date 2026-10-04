import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../services/manual_entry_import_service.dart';

final manualEntryImportServiceProvider = Provider<ManualEntryImportService>((
  ref,
) {
  return ManualEntryImportService(ref.watch(databaseProvider));
});

/// Full `manual_entry_instruction.md` (bundled asset — single source of truth).
final manualEntryInstructionProvider = FutureProvider<String>((ref) {
  return rootBundle.loadString('manual_entry_instruction.md');
});

/// Just the block the user pastes into an AI assistant.
String manualEntryPromptFromInstruction(String markdown) {
  final match = RegExp(
    r'## Instruction to paste into the AI\s*```\n([\s\S]*?)\n```',
  ).firstMatch(markdown);
  return match?.group(1)?.trim() ?? markdown.trim();
}
