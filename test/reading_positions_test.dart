import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_vault/core/storage/reading_positions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'rapid switches remember immediately and serialize durable writes',
    () async {
      final key = readingPositionKey(
        '/library-a/file.md',
        'material',
        'markdown',
      );
      final store = ReadingPositions();
      await store.load();
      store.save(key, {'offset': 1400});
      expect(store.get(key)['offset'], 1400);
      final firstWrite = store.flush();
      store.save(key, {'offset': 2800});
      final secondWrite = store.flush();
      await Future.wait([firstWrite, secondWrite]);
      final reopened = ReadingPositions();
      await reopened.load();
      expect(reopened.get(key)['offset'], 2800);
      store.dispose();
      reopened.dispose();
    },
  );

  test(
    'library, material type, version and language have distinct bookmarks',
    () {
      final keys = {
        readingPositionKey('/a/source', 'm', 'markdown'),
        readingPositionKey('/b/source', 'm', 'markdown'),
        readingPositionKey('/a/source', 'm', 'pdf'),
        readingPositionKey('/a/source', 'm', 'ai:summary:v1:original'),
        readingPositionKey('/a/source', 'm', 'ai:explanation:v1:original'),
        readingPositionKey('/a/source', 'm', 'ai:summary:v2:original'),
        readingPositionKey('/a/source', 'm', 'ai:summary:v1:persian'),
      };
      expect(keys, hasLength(7));
    },
  );

  test('malformed bookmarks cannot prevent opening a reader', () async {
    final key = readingPositionKey('/a', 'm', 'markdown');
    SharedPreferences.setMockInitialValues({key: 'invalid JSON'});
    final store = ReadingPositions();
    await store.load();
    expect(store.get(key), isEmpty);
    store.save(key, {'offset': double.nan});
    expect(store.get(key), isEmpty);
    store.dispose();
  });
}
