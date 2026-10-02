import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import '../../ai_assistant/domain/ai_exceptions.dart';
import '../../ai_assistant/domain/ai_models.dart';

/// Renders a single PDF page to a compact JPEG for Gemini vision.
abstract final class PdfPageImageExtractor {
  static const maxLongestSide = kAiPageImageLongestSide;
  static const maxBytes = kAiMaxPageImageBytes;

  static Future<AiStudyImage> renderJpeg({
    required String filePath,
    required int pageNumber,
  }) async {
    if (pageNumber < 1) {
      throw const AiMalformedOutputException(
        'Could not render this PDF page as an image.',
      );
    }

    final doc = await PdfDocument.openFile(filePath);
    try {
      if (pageNumber > doc.pages.length) {
        throw const AiMalformedOutputException(
          'Could not render this PDF page as an image.',
        );
      }
      final page = doc.pages[pageNumber - 1];
      final longest = page.width > page.height ? page.width : page.height;
      final scale = longest <= maxLongestSide ? 1.0 : maxLongestSide / longest;
      final rendered = await page.render(
        fullWidth: page.width * scale,
        fullHeight: page.height * scale,
      );
      if (rendered == null) {
        throw const AiMalformedOutputException(
          'Could not render this PDF page as an image.',
        );
      }
      try {
        final jpeg = _bgraToJpeg(
          pixels: rendered.pixels,
          width: rendered.width,
          height: rendered.height,
        );
        return AiStudyImage(
          bytes: jpeg,
          mimeType: 'image/jpeg',
          pageNumber: pageNumber,
        );
      } finally {
        rendered.dispose();
      }
    } on AiException {
      rethrow;
    } on Object {
      throw const AiMalformedOutputException(
        'Could not render this PDF page as an image.',
      );
    } finally {
      await doc.dispose();
    }
  }

  static Uint8List _bgraToJpeg({
    required Uint8List pixels,
    required int width,
    required int height,
  }) {
    final decoded = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: pixels.buffer,
      bytesOffset: pixels.offsetInBytes,
      rowStride: width * 4,
      order: img.ChannelOrder.bgra,
      numChannels: 4,
    );

    var quality = 75;
    var encoded = Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
    if (encoded.length > maxBytes) {
      quality = 55;
      encoded = Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
    }
    if (encoded.length > maxBytes) {
      throw const AiSourceTooLargeException();
    }
    return encoded;
  }
}
