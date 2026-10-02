import 'package:flutter_test/flutter_test.dart';
import 'package:study_vault/features/study_workspace/data/study_workspace_providers.dart';
import 'package:study_vault/features/study_workspace/domain/study_workspace_models.dart';

void main() {
  group('StudyWorkspaceController', () {
    test('opens chat and preserves it while minimized', () {
      final controller = StudyWorkspaceController();
      addTearDown(controller.dispose);

      controller.open();
      controller.minimize();

      expect(controller.state.visible, isTrue);
      expect(controller.state.minimized, isTrue);
      expect(controller.state.activeTab, StudyWorkspaceTab.chat);

      controller.restore();
      expect(controller.state.minimized, isFalse);
    });

    test('tracks a PDF page and navigates between workspace tabs', () {
      final controller = StudyWorkspaceController();
      addTearDown(controller.dispose);
      const source = PdfWorkspaceSource(
        materialId: 'material-1',
        title: 'Lecture slides',
        filePath: '/tmp/slides.pdf',
        currentPage: 10,
      );

      controller.attachSource(source, open: true);
      controller.select(StudyWorkspaceTab.deepExplanation);
      controller.updatePdfPage(source.materialId, 11);

      expect(controller.state.activeTab, StudyWorkspaceTab.deepExplanation);
      expect((controller.state.source as PdfWorkspaceSource).currentPage, 11);

      controller.goBack();
      expect(controller.state.activeTab, StudyWorkspaceTab.source);
      controller.goForward();
      expect(controller.state.activeTab, StudyWorkspaceTab.deepExplanation);
    });

    test('does not open PDF-only tabs for image sources', () {
      final controller = StudyWorkspaceController();
      addTearDown(controller.dispose);
      controller.attachSource(
        const ImageWorkspaceSource(
          materialId: 'image-1',
          title: 'Diagram',
          filePath: '/tmp/diagram.png',
        ),
        open: true,
      );

      controller.select(StudyWorkspaceTab.summary);

      expect(controller.state.activeTab, StudyWorkspaceTab.source);
    });
  });
}
