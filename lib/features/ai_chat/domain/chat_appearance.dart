enum ChatMessageLayout { bubbles, fullWidth }

enum ChatBackgroundKind { theme, solid, gradient, image }

enum ChatAppearancePreset { defaultStyle, chatGpt, minimal, amoled }

class ChatAppearance {
  const ChatAppearance({
    this.layout = ChatMessageLayout.bubbles,
    this.backgroundKind = ChatBackgroundKind.theme,
    this.textScale = 1,
    this.userColorValue,
    this.assistantColorValue,
    this.backgroundColorValue,
    this.gradientStartValue,
    this.gradientEndValue,
    this.backgroundImagePath,
    this.backgroundImageOpacity = 0.22,
    this.backgroundImageBlur = 2,
    this.showAvatars = false,
  });

  final ChatMessageLayout layout;
  final ChatBackgroundKind backgroundKind;
  final double textScale;
  final int? userColorValue;
  final int? assistantColorValue;
  final int? backgroundColorValue;
  final int? gradientStartValue;
  final int? gradientEndValue;
  final String? backgroundImagePath;
  final double backgroundImageOpacity;
  final double backgroundImageBlur;
  final bool showAvatars;

  static const defaults = ChatAppearance();

  ChatAppearance copyWith({
    ChatMessageLayout? layout,
    ChatBackgroundKind? backgroundKind,
    double? textScale,
    int? userColorValue,
    int? assistantColorValue,
    int? backgroundColorValue,
    int? gradientStartValue,
    int? gradientEndValue,
    String? backgroundImagePath,
    double? backgroundImageOpacity,
    double? backgroundImageBlur,
    bool? showAvatars,
    bool clearUserColor = false,
    bool clearAssistantColor = false,
    bool clearBackgroundImage = false,
  }) {
    return ChatAppearance(
      layout: layout ?? this.layout,
      backgroundKind: backgroundKind ?? this.backgroundKind,
      textScale: textScale ?? this.textScale,
      userColorValue: clearUserColor
          ? null
          : userColorValue ?? this.userColorValue,
      assistantColorValue: clearAssistantColor
          ? null
          : assistantColorValue ?? this.assistantColorValue,
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      gradientStartValue: gradientStartValue ?? this.gradientStartValue,
      gradientEndValue: gradientEndValue ?? this.gradientEndValue,
      backgroundImagePath: clearBackgroundImage
          ? null
          : backgroundImagePath ?? this.backgroundImagePath,
      backgroundImageOpacity:
          backgroundImageOpacity ?? this.backgroundImageOpacity,
      backgroundImageBlur: backgroundImageBlur ?? this.backgroundImageBlur,
      showAvatars: showAvatars ?? this.showAvatars,
    );
  }

  Map<String, Object?> toJson() => {
    'layout': layout.name,
    'backgroundKind': backgroundKind.name,
    'textScale': textScale,
    'userColorValue': userColorValue,
    'assistantColorValue': assistantColorValue,
    'backgroundColorValue': backgroundColorValue,
    'gradientStartValue': gradientStartValue,
    'gradientEndValue': gradientEndValue,
    'backgroundImagePath': backgroundImagePath,
    'backgroundImageOpacity': backgroundImageOpacity,
    'backgroundImageBlur': backgroundImageBlur,
    'showAvatars': showAvatars,
  };

  factory ChatAppearance.fromJson(Map<String, Object?> json) {
    return ChatAppearance(
      layout: _enumByName(
        ChatMessageLayout.values,
        json['layout'],
        ChatMessageLayout.bubbles,
      ),
      backgroundKind: _enumByName(
        ChatBackgroundKind.values,
        json['backgroundKind'],
        ChatBackgroundKind.theme,
      ),
      textScale: _boundedDouble(json['textScale'], 1, 0.8, 1.5),
      userColorValue: _nullableInt(json['userColorValue']),
      assistantColorValue: _nullableInt(json['assistantColorValue']),
      backgroundColorValue: _nullableInt(json['backgroundColorValue']),
      gradientStartValue: _nullableInt(json['gradientStartValue']),
      gradientEndValue: _nullableInt(json['gradientEndValue']),
      backgroundImagePath: json['backgroundImagePath'] as String?,
      backgroundImageOpacity: _boundedDouble(
        json['backgroundImageOpacity'],
        0.22,
        0,
        0.8,
      ),
      backgroundImageBlur: _boundedDouble(
        json['backgroundImageBlur'],
        2,
        0,
        20,
      ),
      showAvatars: json['showAvatars'] as bool? ?? false,
    );
  }

  factory ChatAppearance.fromPreset(ChatAppearancePreset preset) {
    return switch (preset) {
      ChatAppearancePreset.defaultStyle => ChatAppearance.defaults,
      ChatAppearancePreset.chatGpt => const ChatAppearance(
        layout: ChatMessageLayout.fullWidth,
        userColorValue: 0xffe8f0fe,
        assistantColorValue: 0xfff7f7f8,
        showAvatars: true,
      ),
      ChatAppearancePreset.minimal => const ChatAppearance(
        layout: ChatMessageLayout.fullWidth,
        userColorValue: 0x00ffffff,
        assistantColorValue: 0x00ffffff,
      ),
      ChatAppearancePreset.amoled => const ChatAppearance(
        layout: ChatMessageLayout.bubbles,
        backgroundKind: ChatBackgroundKind.solid,
        backgroundColorValue: 0xff000000,
        userColorValue: 0xff173a2d,
        assistantColorValue: 0xff151515,
      ),
    };
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

double _boundedDouble(
  Object? raw,
  double fallback,
  double minimum,
  double maximum,
) {
  if (raw is! num) return fallback;
  return raw.toDouble().clamp(minimum, maximum);
}

int? _nullableInt(Object? raw) => raw is num ? raw.toInt() : null;
