# StudyDesk refactoring progress

Refactor one small part at a time. Reuse the components StudyDesk already has, then share a new component only when two real callers need the same behavior. Keep each change small enough to review and revert on its own.

## Current progress

- **Baseline** — Review navigation, summary labels, and Advanced Settings were reorganized. That work is separate from the component refactors below.
- **Next** — E. Find a library list that can reuse `AdaptiveItemList` with the same phone and desktop behavior.
- **Completed** — 4 of 26. All unchecked entries are proposals. If inspection shows a shared component would make the callers harder to read, mark the entry **skipped** and record why.

## How to work through one item

1. Read the current widget and its callers. Write down the screens and behaviors the change must cover, including loading, errors, cancellation, accessibility, and narrow or desktop layout when relevant.
2. Try the existing project component first. Plain Flutter and a few readable lines are also fine. Keep data loading, navigation, and feature decisions in the screen unless those behaviors are genuinely shared.
3. Make one change and read the diff in context. A good shared widget has a concrete name, a short constructor, and obvious callers. If it needs caller-specific flags, keep those decisions at the call sites.
4. Run the targeted `flutter test --no-pub` checks listed for the item, `flutter analyze` for Dart changes as required by `AGENTS.md`, and `git diff --check`. Use in-memory databases and temporary files. Add a small regression test when existing coverage misses new behavior.
5. Mark the item done after checking both callers. Add a dated log entry with the files changed, checks and results, and any known limitation. Pick up the next item in a separate pass.

## A to Z checklist

Test filenames below are relative to `test/`.

### Shared UI

| Item | Small change | Existing check |
| --- | --- | --- |
| [x] A. Loading indicators | Use `AppLoading` for full-body loading in Recent Reviews and the flashcard list. Keep the existing loading conditions and all other states. | `desktop_layout_test.dart` |
| [x] B. Empty states | Compare the empty states in the flashcard list and Books shelf. Reuse `EmptyState` where it fits, with each screen’s own copy and action. | `desktop_layout_test.dart`, `reference_books_test.dart` |
| [x] C. Content width | Use `ContentContainer` for the Review hub and Settings with explicit width and the existing list padding. | `desktop_layout_test.dart` |
| [x] D. Search width | Use one `ContentContainer` for Search’s input, filters, and results. | `desktop_layout_test.dart`, `search_favorites_categories_test.dart`, `file_search_test.dart` |
| [ ] E. Adaptive lists | Use `AdaptiveItemList` for one library list that already needs the same phone-list and desktop-grid behavior. Verify ordering and tap targets. | `desktop_layout_test.dart`, `library_reorder_test.dart` |
| [ ] F. Group headers | Compare group rows on the class and subject pages. Reuse `GroupSectionHeader` for matching presentation while each page owns its menu and reorder callbacks. | `library_reorder_test.dart` |
| [ ] G. Delete confirmations | Compare one class or subject delete confirmation with the lesson equivalent. Reuse the existing confirmation dialog where it fits and keep each cascade warning and cancel path. | `library_reorder_test.dart`, `database_test.dart` |

### Readers and review

| Item | Small change | Existing check |
| --- | --- | --- |
| [ ] H. Review links | Compare the pin-review actions in the PDF and image readers with `ReviewEntryButton`. Share the button only if enabled states, counts, and scopes agree. | `study_review_test.dart`, `image_gallery_test.dart` |
| [ ] I. Bookmark actions | Compare the bookmark affordance in the lesson PDF and book readers. Share presentation if it matches and keep their bookmark writes in their respective features. | `reference_books_test.dart`, `pdf_study_dock_test.dart` |
| [ ] J. Download actions | Check one book or lesson reader for download UI that can reuse `DownloadDocumentButton`. Preserve filename, file type, and save or share behavior. | `document_download_test.dart`, `reference_books_test.dart` |
| [ ] K. Image navigation | Keep the current image position, previous and next buttons, and counter together in the image reader. Preserve swipe, zoom, annotation, and missing-file behavior. | `image_gallery_test.dart` |
| [ ] L. Reading positions | Compare save and restore in the PDF and Markdown readers against `reading_positions.dart`. Reuse storage code where it fits and keep each reader’s viewport or scroll logic local. | `pdf_reader_position_test.dart`, `markdown_study_screen_test.dart`, `reading_positions_test.dart` |
| [ ] M. Review actions | Compare the schedule’s lesson-row actions with those in the lesson schedule tile. Reuse `schedule_actions.dart` for matching operations and preserve the existing dates and ratings. | `study_schedule_screen_test.dart`, `study_schedule_test.dart` |
| [ ] N. Markdown rendering | Compare one Markdown rendering path in Course Review with the generated-material reader. Reuse the existing renderer where it preserves code, math, charts, and Persian direction. | `course_review_test.dart`, `chart_markdown_test.dart`, `pdf_ai_translation_reader_test.dart` |

### AI and import

| Item | Small change | Existing check |
| --- | --- | --- |
| [ ] O. Material generation | Follow Generate in `PdfAiMaterialsSheet` and `PdfAiMaterialsPanel`. Reuse `pdf_ai_queue_actions.dart` for any remaining shared queue step. Preserve cancellation and the selected model. | `pdf_ai_material_test.dart`, `ai_generation_queue_test.dart` |
| [ ] P. Copy instructions | Compare Copy Instruction in the same sheet and panel. Share the operation inside the feature if it really matches and leave placement in each screen. | `pdf_ai_material_test.dart` |
| [ ] Q. Generated material actions | Compare the two entry points for importing a saved result. Reuse the existing import dialog and keep the chosen material type and version intact. | `pdf_ai_material_test.dart`, `manual_entry_test.dart` |
| [ ] R. Model selection | Trace one picker caller to the shared model picker and catalog. Remove a redundant selection step only if cancelling still exits and the exact profile and model still reach the request. | `ai_execution_selection_test.dart`, `ai_endpoint_profile_test.dart` |
| [ ] S. Book AI requests | Compare one chapter or page action with `book_ai_request_picker.dart`. Reuse the existing picker while preserving provider checks, page ranges, and extracted text or PDF choices. | `book_ai_providers_test.dart` |
| [ ] T. Selection actions | Compare Save as Note and Make Flashcard in a reader with `SelectionAiToolbar`. Reuse the existing action presentation where it fits and preserve selected text and source ownership. | `selection_ai_test.dart`, `markdown_study_screen_test.dart` |
| [ ] U. Chat launch | Trace one contextual chat launcher and reuse `AiChatNavigation` where the same draft or linked-message behavior is already implemented. Keep source links, draft content, and message focus. | `ai_chat_reverse_refs_test.dart`, `study_workspace_test.dart` |

### Settings and final checks

| Item | Small change | Existing check |
| --- | --- | --- |
| [ ] V. Settings controls | Compare adjacent dropdowns in `AiSettingsSection`. Use the same Flutter pattern for width and labels. Extract a widget only if the repeated setup actually shrinks. | `desktop_layout_test.dart`, `ai_endpoint_profile_test.dart` |
| [ ] W. API profile rows | Read the profile card in `AiEndpointProfilesSection`. Keep related actions together and simplify one repeated UI pattern while preserving key masking and profile selection. | `ai_endpoint_profile_test.dart`, `ai_cache_regression_test.dart` |
| [ ] X. Backup status | Read the progress reporting for create and restore in Settings. Share matching display code only, keeping the confirmation and archive operations separate. | `backup_archive_test.dart`, `backup_restore_paths_test.dart` |
| [ ] Y. Adoption check | Review the callers changed so far. Adopt a proven component in one remaining equivalent caller, if there is one. Remove only wrappers made unused by the refactor. | Targeted tests for that caller |
| [ ] Z. Final review | Smoke-check the library, a reader, Review, AI Chat, and Settings. Compare phone and desktop navigation and run the combined tests for touched features. | `desktop_layout_test.dart` and the targeted tests recorded below |

## Progress log

| Date | Item | Files and outcome | Checks and follow-up |
| --- | --- | --- | --- |
| 2026-11-18 | Baseline | Recorded the refactor sequence. Start with Recent Reviews and the flashcard list. | The preceding navigation work passed focused checks. Separate older schema assertions in the quiz and chat-reference tests expected version 22 while the app uses 24. |
| 2026-11-18 | A. Loading indicators | `recent_reviews_screen.dart` and `flashcards_list_screen.dart` now use `AppLoading`. | All 8 desktop layout tests passed. `flutter analyze --no-pub` reported 8 existing informational findings outside these files. |
| 2026-11-18 | B. Empty states | `flashcards_list_screen.dart` now uses `EmptyState`, with a hint for making a card from selected PDF text. | All 26 desktop layout and reference book tests passed. `flutter analyze --no-pub` reported 8 existing informational findings outside the edited file. |
| 2026-11-18 | C. Content width | `review_hub_screen.dart` and `settings_screen.dart` use `ContentContainer`. `desktop_layout_test.dart` checks the desktop Review and phone Settings widths. | All 8 layout tests passed on retry. `flutter analyze --no-pub` reported 8 existing informational findings outside the edited files. |
| 2026-11-18 | D. Search width | `search_screen.dart` uses one width and horizontal padding for the whole body. `file_search_test.dart` checks field, scope chip, and result alignment at phone and desktop widths. | All 37 focused tests passed. `flutter analyze --no-pub` reported 8 existing informational findings outside the edited files. |
