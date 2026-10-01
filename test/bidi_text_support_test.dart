import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/core/text/search_text_normalizer.dart';
import 'package:study_vault/core/text/text_direction_utils.dart';

void main() {
  group('TextDirectionUtils', () {
    test('Persian-only → RTL', () {
      expect(
        TextDirectionUtils.resolve(
          'گرادیان نزولی یکی از الگوریتم‌های مهم یادگیری ماشین است',
        ),
        TextDirection.rtl,
      );
    });

    test('English-only → LTR', () {
      expect(TextDirectionUtils.resolve('Gradient Descent'), TextDirection.ltr);
    });

    test('mixed starting with English → LTR', () {
      expect(
        TextDirectionUtils.resolve(
          'Gradient Descent یک الگوریتم بهینه‌سازی است.',
        ),
        TextDirection.ltr,
      );
    });

    test('mixed starting with Persian → RTL', () {
      expect(
        TextDirectionUtils.resolve(
          'در Machine Learning ما Cost Function را کم می‌کنیم.',
        ),
        TextDirection.rtl,
      );
    });

    test('formula / numbers alone → fallback LTR', () {
      expect(TextDirectionUtils.resolve('α = 0.01'), TextDirection.ltr);
      expect(TextDirectionUtils.resolve('θ = θ - α ∂J/∂θ'), TextDirection.ltr);
    });

    test('Persian sentence with formula → RTL', () {
      expect(
        TextDirectionUtils.resolve(
          'اگر α = 0.01 باشد، Learning Rate کوچک است.',
        ),
        TextDirection.rtl,
      );
    });
  });

  group('SearchTextNormalizer', () {
    test('maps Arabic Yeh (U+064A) to Persian Yeh (U+06CC)', () {
      const arabicYehForm = 'گراد\u064Aان';
      const persianYehForm = 'گراد\u06CCان';
      expect(
        SearchTextNormalizer.normalize(arabicYehForm),
        SearchTextNormalizer.normalize(persianYehForm),
      );
    });

    test('maps Arabic Kaf (U+0643) to Persian Kaf (U+06A9)', () {
      const arabicKafForm = '\u0643وچ\u0643';
      const persianKafForm = '\u06A9وچ\u06A9';
      expect(
        SearchTextNormalizer.normalize(arabicKafForm),
        SearchTextNormalizer.normalize(persianKafForm),
      );
    });

    test('does not alter Latin search terms', () {
      expect(SearchTextNormalizer.normalize('Gradient'), 'gradient');
    });

    test('does not mutate caller string content', () {
      const original = 'گرادیان نزولی';
      final normalized = SearchTextNormalizer.normalize(original);
      expect(normalized, isNotEmpty);
      expect(original, 'گرادیان نزولی');
    });
  });
}
