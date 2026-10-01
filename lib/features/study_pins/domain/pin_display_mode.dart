/// How Study Pins are shown over a PDF page or image.
enum PinDisplayMode {
  hidden,
  dotsOnly,
  dotsAndText,
}

extension PinDisplayModeLabel on PinDisplayMode {
  String get label => switch (this) {
        PinDisplayMode.hidden => 'Hidden',
        PinDisplayMode.dotsOnly => 'Dots',
        PinDisplayMode.dotsAndText => 'Dots + Text',
      };
}
