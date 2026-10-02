import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/study_workspace/data/study_workspace_providers.dart';

void main() {
  group('StudyWorkspaceController', () {
    test('opens chat and preserves it while minimized', () {
      final controller = StudyWorkspaceController();
      addTearDown(controller.dispose);

      controller.open();
      controller.minimize();

      expect(controller.state.visible, isTrue);
      expect(controller.state.minimized, isTrue);

      controller.restore();
      expect(controller.state.minimized, isFalse);
    });

    test('close hides the floating chat', () {
      final controller = StudyWorkspaceController();
      addTearDown(controller.dispose);
      controller.open();
      controller.close();

      expect(controller.state.visible, isFalse);
      expect(controller.state.minimized, isFalse);
    });
  });
}
