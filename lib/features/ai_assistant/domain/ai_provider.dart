/// Study Vault AI backends. Features must stay provider-agnostic;
/// provider-specific transport lives in infrastructure services.
enum AiProviderId { gemini, deepseek, newApi }

extension AiProviderIdX on AiProviderId {
  String get storageValue => name;

  String get displayName => switch (this) {
    AiProviderId.gemini => 'Gemini',
    AiProviderId.deepseek => 'DeepSeek',
    AiProviderId.newApi => 'New API (Claude)',
  };

  /// Short privacy line for Settings / consent.
  String get privacyLine => switch (this) {
    AiProviderId.gemini =>
      'Study content used in AI requests is sent to Gemini.',
    AiProviderId.deepseek =>
      'Study content used in AI requests is sent to DeepSeek.',
    AiProviderId.newApi =>
      'Study content used in AI requests is sent to your New API server.',
  };

  static AiProviderId fromStorage(String? raw) {
    final value = raw?.trim().toLowerCase();
    return switch (value) {
      'deepseek' => AiProviderId.deepseek,
      'newapi' => AiProviderId.newApi,
      _ => AiProviderId.gemini,
    };
  }

  /// Infer provider from a persisted model id (chat history, etc.).
  static AiProviderId fromModelId(String? modelId) {
    final id = modelId?.trim().toLowerCase() ?? '';
    if (id.startsWith('deepseek')) return AiProviderId.deepseek;
    if (id.startsWith('newapi:')) return AiProviderId.newApi;
    return AiProviderId.gemini;
  }
}

/// DeepSeek thinking / reasoning effort (never shown as content to users).
enum AiThinkingMode { auto, low, high, max }

extension AiThinkingModeX on AiThinkingMode {
  String get storageValue => name;

  String get label => switch (this) {
    AiThinkingMode.auto => 'Auto',
    AiThinkingMode.low => 'Low',
    AiThinkingMode.high => 'High',
    AiThinkingMode.max => 'Max',
  };

  static AiThinkingMode fromStorage(String? raw) {
    final value = raw?.trim().toLowerCase();
    return switch (value) {
      'low' => AiThinkingMode.low,
      'high' => AiThinkingMode.high,
      'max' => AiThinkingMode.max,
      _ => AiThinkingMode.auto,
    };
  }
}

/// Capability flags so UI / features can gate provider-specific options.
class AiProviderCapabilities {
  const AiProviderCapabilities({
    this.text = true,
    this.structuredJson = true,
    this.streaming = false,
    this.vision = false,
    this.thinking = false,
    this.tools = false,
  });

  final bool text;
  final bool structuredJson;
  final bool streaming;
  final bool vision;
  final bool thinking;
  final bool tools;

  static const gemini = AiProviderCapabilities(
    text: true,
    structuredJson: true,
    streaming: true,
    vision: true,
    thinking: false,
    tools: false,
  );

  static const deepseek = AiProviderCapabilities(
    text: true,
    structuredJson: true,
    streaming: true,
    vision: false,
    thinking: true,
    tools: true,
  );

  static const newApi = AiProviderCapabilities(
    text: true,
    structuredJson: true,
    streaming: true,
  );

  static AiProviderCapabilities forProvider(AiProviderId id) => switch (id) {
    AiProviderId.gemini => gemini,
    AiProviderId.deepseek => deepseek,
    AiProviderId.newApi => newApi,
  };
}
