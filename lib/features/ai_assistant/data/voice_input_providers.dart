import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_settings_store.dart';
import '../services/voice_input_service.dart';

/// App-wide speech recognizer (one active listen session).
///
/// Kept separate from [ai_providers] so UI/tests do not pull Drift.
final voiceInputServiceProvider = ChangeNotifierProvider<VoiceInputService>((
  ref,
) {
  // ChangeNotifierProvider disposes the notifier automatically.
  return VoiceInputService();
});

/// Settings used only for voice locale preference (same store as AI settings).
final voiceAiSettingsStoreProvider = Provider<AiSettingsStore>((ref) {
  return SharedPreferencesAiSettingsStore();
});
