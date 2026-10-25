# Study Vault — assistant brief

You are working on **Study Vault**, a local-first Flutter study app (version `4.0.0+6000`, Dart SDK `^3.12.2`). This file is the source of truth for the product, the code map, the database, and the rules you must follow. Read it before you design, write, or change anything.

Repo root: the Flutter project that contains `lib/`, `test/`, `sync-server/`, `tool/study_vault_mcp.py`, `manual_entry_instruction.md`, and `AGENTS.md`. Keep this brief and `AGENTS.md` aligned; this brief is the product and architecture source of truth, while `AGENTS.md` is the short operational checklist.

---

## How you must work

You are responsible for these three rules on every request.

### 1. Act from this brief when it already answers the question

If this document (and the conversation that includes it) already contains the facts you need, implement or answer from those facts. Do not invent tables, routes, sync behavior, file paths, or AI contracts that contradict this brief.

Match existing patterns:

- Flutter UI and state live under `lib/features/<feature>/` with `presentation/`, `data/`, `domain/`, and `services/` as that feature already uses them.
- State is Riverpod. Persistence is Drift (`lib/core/database/app_database.dart`) plus a few raw SQLite tables that must stay out of Drift.
- IDs are text UUIDs. Timestamps stored by Drift are unix seconds (`INTEGER` in SQLite). Calendar days for the study schedule are `yyyy-MM-dd` text, never timestamps.
- Rich notes and pin explanations are Quill Delta JSON, with a plain-text column for search.
- New synced columns require a schema bump. See “Changing the database” below.

### 2. When this brief is missing a fact, ask Cursor — do not guess

If a detail is absent or too thin here (exact function body, a widget you have not seen, a migration step, a prompt string, a test assertion), stop and give the user **one complete prompt** they can paste into Cursor in this repo. Wait for the user’s paste of Cursor’s answer before you continue.

Use this shape, filled in for the actual gap:

```text
You are in the Study Vault repo. Do not change any files. Investigate only, then answer with file paths, symbol names, and short quoted code.

Question:
<one precise question>

Look in:
- <likely files or globs>

Report:
1. The exact current behavior, with file path and line numbers.
2. The types, enums, and storage values involved.
3. The tests that already cover it (paths under test/).
4. Any invariant that a change would break (sync, schema version, cascade deletes, device-local tables).
5. If the thing does not exist, say so plainly.
```

Ask for one missing fact per prompt when you can. Batch only facts that live in the same files.

### 3. When you build or change something, use a prompt that forces the right design

Before a large change, write the user a **prompt-engineered Cursor prompt** (templates are at the end of this file). The prompt must name the feature folder, the tables, the tests to run, and the invariants that must stay true. Prefer extending the existing feature over a new architecture.

---

## What the app is

Study Vault organizes a student’s library on the device and optionally syncs that library to a private server.

Hierarchy:

```text
Class
  └── SubjectGroup (optional)
        └── Subject  (optional exam_date)
              └── LessonGroup (optional)
                    └── Lesson  (progress: notStarted | studying | reviewed | mastered)
                          └── LessonMaterial  (PDF, image, text, or interactive HTML)
                                └── Study pins, bookmarks, AI materials, quizzes
```

A subject can also hold notes, flashcards, a Course Review, a study schedule, and links to reference books. A class can hold a roadmap: an ordered list of existing lessons.

The app is **local-first**. One device can hold multiple independent **library accounts**. Each library has its own SQLite database, material files, backups, AI queue, and optional cloud session. Switching libraries tears down the old Riverpod scope before opening the next one. The default library (initially named `Personal`) keeps the legacy documents-root paths; additional libraries live under `study_vault_accounts/{uuid}/`.

Cloud sync is manual and opt-in. AI calls are user-initiated and send only the selected study text or selected document, never the whole library. Interactive HTML is never sent to AI.

Platforms: Android, and desktop (Linux, Windows, macOS). Phones and windows narrower than 1000px use the mobile shell. Desktop uses a persistent left rail.

---

## Stack

| Piece | Choice |
| --- | --- |
| UI | Flutter, Material 3, `flutter_riverpod` |
| Local DB | Drift + SQLite (`sqlite3_flutter_libs`) |
| Rich text | `flutter_quill` (notes, pin explanations, flashcard backs) |
| PDF | `pdfrx` |
| Markdown / math / charts | `flutter_markdown`, `flutter_math_fork`, `fl_chart` |
| AI HTTP | `http` to Gemini, DeepSeek, or named “New API” Anthropic Messages-compatible endpoint profiles |
| Interactive HTML | `webview_flutter` where supported; loopback `HttpServer`; Linux GTK WebKit helper or browser fallback; `url_launcher` |
| Secrets | `flutter_secure_storage` for API keys, endpoint-profile keys, and per-library cloud sessions. Never store session tokens in `local_cloud_sync` |
| Preferences | `shared_preferences` (daily review limit, chat appearance, endpoint-profile metadata, and similar device-only settings) |
| Cloud | `sync-server/` — production Docker uses Node 24; package engines allow Node ≥22; Express + PostgreSQL. Protocol v2: `GET /v2/snapshot`, `POST /v2/sync` |
| External writer | `tool/study_vault_mcp.py` — Python stdlib MCP over stdio. Reads and adds to the local SQLite file. Never deletes study content. Writes preview unless `apply: true` |

---

## Navigation

Routes are named constants in `lib/app/routes.dart`. The root widget is `StudyVaultApp` in `lib/app/app.dart`. It wraps every route in `DesktopFrame` and `StudyWorkspaceHost`.

Shell tabs (`lib/core/navigation/shell_tab.dart`): **Home** and **AI Chat** live inside `AppShell`. Other screens are pushed routes.

| Route | Screen |
| --- | --- |
| `/` | Home library (`AppShell`, home tab) |
| `/ai-chat` | AI Chat tab |
| `/class` | Class details |
| `/class/roadmap` | Class roadmap |
| `/subject` | Subject details |
| `/lesson` | Lesson details |
| `/pdf-study` | PDF reader |
| `/image-study` | Image reader |
| `/markdown-study` | Markdown material reader |
| `/html-study` | Interactive HTML material reader |
| `/lesson-images` | Lesson image gallery |
| `/lesson-summary` | One editable summary for a lesson |
| `/note` `/note/edit` | Note reader / editor |
| `/flashcards` `/flashcards/study` | Flashcard list / study |
| `/ai-questions` | Question sets |
| `/manual-entry` | JSON manual-entry import |
| `/course-review` | Subject Course Review |
| `/generation-center` | Device-local AI generation queue and job recovery |
| `/books` `/book` | Reference-book shelf / book details |
| `/schedule` | Study Schedule |
| `/reviews` | Recent pin-review sessions |
| `/favorites` | Favorites |
| `/search` | Global search |
| `/settings` | Settings (optional `section` argument) |

`GenerationQueueHost` wraps the routed app so queue progress and attention states remain visible above navigation.

Desktop rail (`DesktopFrame`, width ≥ 1000 on desktop OS): Library, Books, Search, Schedule, Favorites, Recent Reviews, Settings. It also exposes the active library-account switcher.

Use `AppSpacing.contentWidth(context)` for content width and `AdaptiveItemList` for lists that become grids on desktop. Do not hard-code an 840px max width.

---

## Features

Each feature folder is `lib/features/<name>/`. Typical split: `presentation/` (widgets), `data/` (repositories, Riverpod), `domain/` (pure models), `services/` (AI, import, scheduling).

### Library: classes, subjects, lessons

- `classes/` — top-level containers. Home screen lists classes.
- `subjects/` — belong to a class, optionally a subject group. `exam_date` is optional `yyyy-MM-dd` and feeds the study schedule.
- `lessons/` — belong to a subject, optionally a lesson group. Progress is `notStarted | studying | reviewed | mastered`. Materials are PDFs, images, markdown, plain text, or interactive HTML files stored on disk. A Persian PDF is a language variant: `language = fa`, `variant_of_id` points at the original, `page_offset` maps pages (`persianPage = originalPage + pageOffset`). Unique key `(variant_of_id, language)`.
- Files: `{active library}/study_vault_files/lessons/{lessonId}/{storedFileName}`. App-created markdown, HTML, and HTML bundle files use `{id}.md`, `{id}.html`, and `{id}.zip`.
- PDF, markdown, and plain-text materials are study documents usable by AI Study Materials and Course Review. Images and interactive HTML are not.
- `lesson_summary` — one deterministic lesson-owned `study_notes` row per lesson, editable at `/lesson-summary`. A generated PDF AI summary can append to it.
- `class_roadmap/` — ordered lessons inside a class. One row per `(class_id, lesson_id)`.

### Interactive HTML

`interactive_html/` imports one `.html` page (`text/html`) or a `.zip` bundle containing `index.html` plus CSS, JavaScript, and images (`application/vnd.study-vault.html-bundle+zip`). It can also save pasted HTML.

- HTML materials are ordinary `lesson_materials` rows and sync through `material_files`; no Drift schema bump is required.
- They are excluded from AI Study Materials, Course Review, and chat context.
- Opening unpacks to the temporary `study_vault_html/{materialId}/` cache. Zip-slip is rejected; bundles allow at most 5,000 entries and 512 MiB unpacked; imported files remain subject to the 256 MiB sync file limit.
- A loopback server exposes only the opened material folder, with a per-open path token and stable per-item port so each page retains separate `localStorage`.
- Android, iOS, and macOS use `webview_flutter`. Linux uses a Python GTK WebKit2 4.1 helper when installed and otherwise opens the browser. Windows uses the browser.
- Website state and Linux `study_vault_html_webdata` are device-local and never sync. Remote references produce a **Uses internet** badge.

### Study pins, notes, bookmarks, favorites

- `study_pins/` — annotations on a PDF page or image. `pin_type` is `point` or `text`. Text pins store rectangles in `study_pin_text_ranges`. Optional category (Definition, Important, Formula, Question, Example, Exam, Confusing — seeded in `built_in_data.dart`). `full_explanation` is Quill Delta JSON; `full_explanation_plain_text` is for search. `deleted_at` is reserved; the UI hard-deletes.
- `notes/` — rich notes owned by exactly one of subject or lesson. Same Quill codec.
- Bookmarks — one row per material page in `material_bookmarks`.
- `favorites/` — polymorphic `(entity_type, entity_id)`, unique together.
- `search/` — local search over plain-text columns (`study_search_service.dart`, `search_text_normalizer.dart`).

### Review and schedule

- `study_review/` — recall sessions over pins. Scope is `lesson | material | subject | favorites`. Ratings: `again | hard | good | easy`. Events cascade when the pin or session is deleted.
- `study_schedule/` — lesson-level spaced review. Setting a lesson to Reviewed or Mastered (`setLessonProgress`) enrolls it. Opening a lesson does not. One `study_schedules` row per lesson (minimal, so two offline enrolls merge). Due date lives only on the latest `study_schedule_events` row (`sequence_number`, then `created_at`). Event kinds: `start | review | reschedule`. Days are `yyyy-MM-dd`.
  - Ladder: 1, 3, 7, 21, 60, 120, 240, 365 days. Easy skips a rung. Hard ×1.2. Again → 1 day.
  - Late success is credited for the real gap. Early success never pulls a due date closer.
  - Exam cap: 40% of days left before `subjects.exam_date`. Setting an exam date pulls later reviews forward.
  - A successful review with interval ≥ 60 days marks the lesson mastered. Again marks it reviewed.
  - Daily limit is device-local SharedPreferences, not a synced column.
- `flashcards/` — separate objects, optional link to one source pin (unique `source_study_pin_id`). Back is Quill. Review events are append-only with `reviewed_on`, `due_on`, `interval_days`, `sequence_number`.
- `study_workspace/` — in-memory overlay (visible / minimized). Not persisted.

### AI

Providers (`AiProviderId`): `gemini`, `deepseek`, `newApi`. Features stay provider-agnostic; transport is in `*_ai_service.dart` / `*_chat_service.dart`, and `routing_ai_service.dart` picks the provider.

- Gemini supports multiple keys. DeepSeek supports its defined thinking modes.
- New API supports any number of named Anthropic Messages-compatible endpoint profiles. Profile metadata and cached model IDs live in device-local SharedPreferences under `ai_endpoint_profiles_v1`; each key lives only in secure storage as `study_vault_ai_endpoint_key_<profileId>`.
- A model choice is an `AiModelRef`; a custom model identity includes endpoint profile and model (`sv1:endpoint:<profileId>:<modelId>`). `AiExecutionSelection` captures provider, requested/resolved model, profile, and thinking mode for the request. Chats, annotation calls, and queue jobs use that captured selection instead of re-reading global settings mid-request.
- The legacy single New API URL/key/model migrates once into a profile named **New API**. Profiles, keys, and model preferences are device-local and do not sync.

- `ai_assistant/` — selection and annotation actions: explain, simplify, rephrase, fix grammar, organize, summarize, define, give example, translate, ask, custom prompt, create annotation, flashcards, questions, key concepts, exam points. Languages include English and Persian Dari. Each completed call inserts an immutable `annotation_ai_generations` row. Regenerate adds a new row; `response_text` is never edited. `response_kind`: `text | flashcards | questions | annotation`.
- `selection_ai/` — AI on a markdown/text selection inside readers.
- `ai_chat/` — local conversations. Roles: `user | assistant | system`. Context chips and `@` mentions (lesson, material, note, study pin) are JSON on the message and also indexed in `ai_message_context_refs` for reverse lookup. Draft text and draft chips are stored on the chat. Chat can speak (TTS) and take dictation.
- `ai_generation_queue/` — device-local FIFO queue for PDF/text-document AI materials, continuations, and Persian translations. At most two jobs run concurrently. The Generation Center supports cancel, retry, continue partial output, profile replacement, and opening saved results. Provider keys and session tokens are never stored in jobs. Partial provider output belongs to the job until explicitly completed/saved. Restarted running jobs become `partial` or `interrupted`; the provider request does not survive process death. Deleting an endpoint profile marks affected jobs `configuration_required`. This build has in-app notices only, not OS notifications.
- `pdf_ai_materials/` — versioned whole-document artifacts for PDF, markdown, and plain text. Types: `summary`, `explanation`, `deep_explanation`, `real_world_examples`, `slideshow`. Unique `(material_id, type, version)`. New generation inserts the next version; it does not overwrite. `source_fingerprint` hashes the source. Slideshow slides are separated by `<!-- slide -->`. Long-running work uses the AI generation queue.
  - Persian translation: one `pdf_ai_material_translations` row per source version + language `fa`. The reader splits the original into segments, translates each segment with code, formulas, charts, and slide markers replaced by `⟦SVn⟧` placeholders, and stores the result joined by `<!-- sv-segment -->` so section N matches section N. The EN | فا toggle restores the same section. `source_hash` marks a translation stale after the original is edited. Code, charts, and notation stay LTR.
- `ai_questions/` — question sets. Source types include `selected_text`, `page`, `pages`, `material`, `annotations`, `notes`, `annotations_and_notes`, and the AI material types. Question types: `mcq | true_false | short_answer | fill_blank | mixed`. Difficulty: `easy | medium | hard | mixed`. Attempts and answers are stored. There is a live quiz session as well as a stored quiz session. Mode on attempts is `study` (exam is reserved).
- `course_review/` — one complete Markdown review document per subject. The current document is the latest `course_review_entries` row with `part = document` and null `material_id`; every save appends a version. The screen copies one external prompt, accepts/edits the returned Markdown, and tracks staleness through a fingerprint of every included PDF/text document and its current source fingerprint. Exclusions live in `course_review_exclusions` (unique on `material_id`) and affect that fingerprint.
  - Legacy per-material rows (`summary`, `explanation`, `deep_explanation`) and subject-wide rows (`examples`, `big_picture`) remain readable and can be compiled into a document, but they are no longer the primary editor.
  - Legacy section generation prefers the material’s latest lesson Summary/Explanation over raw source text.
  - JSON import using the `course_review` key still imports legacy sections and needs only a subject. The complete-document external prompt is `CourseReviewPrompts.completeReviewPrompt`; `manual_entry_instruction.md` remains the contract for legacy JSON import.
- `manual_entry/` — import AI-produced JSON into lessons, materials, notes, flashcards, quizzes, and course review. The instruction the outside model must follow is `manual_entry_instruction.md` (also a Flutter asset).

### Reference books

`reference_books/`. PDFs at `{active library}/study_vault_files/books/{bookId}/{storedFileName}`.

Synced tables: `reference_books`, `reference_book_subjects`, `reference_book_chapters`, `reference_book_ai_items`, `reference_book_notes`, `reference_book_messages`, `reference_book_links`, `reference_book_quizzes`.

- Chapters: `level` 0 = chapter, 1 = section. Status `notStarted | reading | done`.
- AI items are versioned per `(book_id, kind, scope_key)`. Kinds: `brief | summary | explanation`. `scope_key` is a chapter id or `pages:{start}-{end}`.
- Notes: a bookmark is a note with empty content.
- Links: lecture PDF → page ranges, priority `must | skim | optional`.
- Quizzes point at a normal `question_sets` row.
- Ask-the-book sends at most 14 retrieved pages. Long chapters are chunk-digested first. The model never receives the whole book.
- Device-local only (raw SQL in `beforeOpen`, **not** Drift, **not** synced, **not** in backups-by-table):
  - `local_book_pages (book_id, page, text)`
  - `local_book_vectors (book_id, page, model, vector)` — optional Gemini `gemini-embedding-001` at 768 dimensions
  - `local_book_state (book_id, stored_file_name, indexed_pages, page_count, last_page, vectors_model)`
- Search is pure-Dart BM25 (`BookTextIndex`) fused with cosine rank when vectors exist.
- Lesson pins and bookmarks are foreign-keyed to `lesson_materials`, so books use their own reader and `reference_book_notes`.

### Settings, backup, cloud

- `settings/` — API keys, endpoint profiles, model choice, backup export, sync recovery export, library accounts, appearance.
- `library_accounts/` — creates, renames, switches, and permanently deletes independent local libraries. The default library (initially `Personal`) cannot be deleted. Switching replaces the root `ProviderScope`, closing the old database, cloud state, and AI queue before opening the selected library.
- `core/backup/` — local archive of the SQLite library and material files. `kStudyVaultSchemaVersion` must equal `AppDatabase.schemaVersion` (currently **24**).
- `cloud_account/` — login, snapshot, sync, merge. Secure sessions are keyed per library account; the default library retains the legacy secure-storage key. See “Cloud sync” below.
- `file-share-server/` — a separate **unauthenticated** LAN sharing tool. It is not the private API. Do not document or expose it as the authenticated backend.

---

## On-disk layout

```text
{application documents}/
  study_vault.sqlite           # default Personal library; plus -wal / -shm
  study_vault_files/
    lessons/{lessonId}/{storedFileName}
    books/{bookId}/{storedFileName}
  study_vault_last_backup.json
  study_vault_sync_recovery/
  study_vault_accounts/
    default.json               # default account display metadata
    active                     # active library account id
    {uuid}/
      account.json
      study_vault.sqlite       # plus -wal / -shm
      study_vault_files/
        lessons/{lessonId}/{storedFileName}
        books/{bookId}/{storedFileName}
      study_vault_last_backup.json
      study_vault_sync_recovery/

{temporary directory}/
  study_vault_html/{materialId}/

{platform application data}/
  study_vault_html_webdata/    # Linux WebKit website data; device-local
```

The MCP default path is `~/Documents/study_vault.sqlite` via `STUDY_VAULT_DB`, so it targets the default library unless `STUDY_VAULT_DB` is set to another library’s database. The app sets `PRAGMA busy_timeout = 10000` and `foreign_keys = ON`. `AppDatabase.watchExternalChanges()` polls `PRAGMA data_version` so open screens refresh after the MCP tool writes.

Tests must use `AppDatabase.forTesting(NativeDatabase.memory())`. Never write the live database during tests.

---

## Database — local SQLite (pseudo schema)

Schema version: **24** (`AppDatabase.schemaVersion`, `kStudyVaultSchemaVersion`, `sync-server/src/store.js`, `sync-server/src/library-schema.json`).

All of these are Drift tables (39). Primary key is `id TEXT` unless noted. `created_at` / `updated_at` are unix-second integers. Foreign keys cascade only where `onDelete` is stated; otherwise they are plain references.

```text
classes
  id, name[1..200], description?, sort_order=0, created_at, updated_at

subject_groups
  id, class_id -> classes, name, description?, sort_order=0,
  created_at, updated_at

subjects
  id, class_id -> classes,
  subject_group_id? -> subject_groups,
  name, description?, sort_order=0,
  exam_date?          -- 'yyyy-MM-dd'
  created_at, updated_at

lesson_groups
  id, subject_id -> subjects, name, description?, sort_order=0,
  created_at, updated_at

lessons
  id, subject_id -> subjects,
  lesson_group_id? -> lesson_groups,
  name, description?, sort_order=0,
  progress_status='notStarted'   -- notStarted|studying|reviewed|mastered
  last_studied_at?, progress_updated_at?,
  created_at, updated_at

lesson_materials
  id, lesson_id -> lessons,
  title[1..300], original_file_name, stored_file_name,
  mime_type='application/pdf', sort_order=0,
  language?,                     -- null or 'fa'
  variant_of_id? -> lesson_materials ON DELETE CASCADE,
  page_offset=0,
  created_at, updated_at
  UNIQUE (variant_of_id, language)

study_pin_categories
  id, name[1..80], color_value, icon_key?, sort_order=0,
  is_system=true, created_at, updated_at

study_pins
  id, resource_id -> lesson_materials,
  pin_type='point',              -- point|text
  category_id? -> study_pin_categories,
  page_number?,                  -- 1-based; null for images
  x_ratio, y_ratio,              -- 0..1
  short_text[1..500],
  full_explanation?,             -- Quill delta JSON or legacy plain text
  full_explanation_plain_text?,
  selected_text?, sort_order?,
  created_at, updated_at, deleted_at?

study_pin_text_ranges
  id, study_pin_id -> study_pins,
  page_number, x_ratio, y_ratio, width_ratio, height_ratio, sort_order=0

favorites
  id, entity_type, entity_id, created_at
  UNIQUE (entity_type, entity_id)

study_review_sessions
  id, scope_type,                -- lesson|material|subject|favorites
  scope_id?, title, started_at, completed_at?,
  total_items, reviewed_items=0, shuffle=false, created_at

study_review_events
  id,
  study_pin_id -> study_pins ON DELETE CASCADE,
  session_id -> study_review_sessions ON DELETE CASCADE,
  rating,                        -- again|hard|good|easy
  reviewed_at, response_time_ms?, created_at

material_bookmarks
  id, material_id -> lesson_materials ON DELETE CASCADE,
  page_number, title?, created_at, updated_at
  UNIQUE (material_id, page_number)

study_notes
  id,
  subject_id? -> subjects ON DELETE CASCADE,
  lesson_id? -> lessons ON DELETE CASCADE,
  title[1..300], content,        -- Quill delta JSON
  plain_text_content?, sort_order=0,
  created_at, updated_at, deleted_at?
  -- exactly one parent is set by application code

flashcards
  id,
  subject_id? -> subjects ON DELETE CASCADE,
  lesson_id? -> lessons ON DELETE CASCADE,
  source_study_pin_id? -> study_pins ON DELETE SET NULL,
  front, back,                   -- back is Quill delta JSON
  back_plain_text?, sort_order?,
  created_at, updated_at, deleted_at?
  UNIQUE (source_study_pin_id)

flashcard_review_events
  id, flashcard_id -> flashcards ON DELETE CASCADE,
  rating, reviewed_on, due_on,   -- days as text
  interval_days, sequence_number, created_at

ai_chats
  id, title[1..120], model_id, created_at, updated_at, last_message_at?,
  draft_text?, draft_context_json?

ai_chat_messages
  id, chat_id -> ai_chats ON DELETE CASCADE,
  role,                          -- user|assistant|system
  content, status?,              -- ok|error|null
  context_json?, created_at,
  ai_provider?, ai_model?,
  prompt_tokens?, completion_tokens?, total_tokens?,
  cache_hit_tokens?, cache_miss_tokens?, request_duration_ms?

ai_message_context_refs
  id,
  message_id -> ai_chat_messages ON DELETE CASCADE,
  chat_id -> ai_chats ON DELETE CASCADE,
  context_type,                  -- lesson|material|note|studyPin
  context_id, created_at
  UNIQUE (message_id, context_type, context_id)
  -- context_json on the message remains the source of truth for packed text

annotation_ai_generations
  id,
  annotation_id? -> study_pins ON DELETE SET NULL,
  material_id? -> lesson_materials ON DELETE SET NULL,
  lesson_id? -> lessons ON DELETE SET NULL,
  page_number?, source_fingerprint, action_type, input_text,
  context_snapshot?, custom_prompt?, action_mode?,
  response_text,                 -- immutable after insert
  response_kind='text',          -- text|flashcards|questions|annotation
  language?, model_name?, provider='gemini', prompt_version?,
  parent_generation_id?, generation_number,
  linked_question_set_id?, linked_flashcard_batch_id?,
  prompt_tokens?, completion_tokens?, total_tokens?,
  cache_hit_tokens?, cache_miss_tokens?, request_duration_ms?,
  created_at, updated_at
  UNIQUE (source_fingerprint, action_type, generation_number)

pdf_ai_materials
  id, material_id -> lesson_materials ON DELETE CASCADE,
  type,                          -- summary|explanation|deep_explanation|real_world_examples|slideshow
  content, version, generated_at,
  provider?, model?, token columns..., request_duration_ms?,
  source_fingerprint, custom_instruction?
  UNIQUE (material_id, type, version)

pdf_ai_material_translations
  id, source_id -> pdf_ai_materials ON DELETE CASCADE,
  language,                      -- 'fa'
  content, source_hash,
  provider?, model?, token columns..., request_duration_ms?,
  created_at, updated_at
  UNIQUE (source_id, language)

question_sets
  id,
  material_id? -> lesson_materials ON DELETE SET NULL,
  lesson_id? -> lessons ON DELETE SET NULL,
  subject_id? -> subjects ON DELETE SET NULL,
  title, source_type, source_reference?,
  question_count, question_type, difficulty,
  ai_provider='gemini', ai_model?, token columns...,
  created_at, updated_at

quiz_questions
  id, question_set_id -> question_sets ON DELETE CASCADE,
  type,                          -- mcq|true_false|short_answer|fill_blank
  question, correct_answer, explanation?, difficulty?,
  source_page?, source_text?, position,
  created_at, updated_at

quiz_question_options
  id, question_id -> quiz_questions ON DELETE CASCADE,
  option_text, is_correct, position

quiz_attempts
  id, question_set_id -> question_sets ON DELETE CASCADE,
  started_at, completed_at?, score?, total_questions, mode='study'

quiz_answers
  id,
  quiz_attempt_id -> quiz_attempts ON DELETE CASCADE,
  question_id -> quiz_questions ON DELETE CASCADE,
  selected_option_id?, answer_text?, is_correct?

course_review_entries
  id, subject_id -> subjects ON DELETE CASCADE,
  material_id? -> lesson_materials ON DELETE CASCADE,
  -- null for document|examples|big_picture; set for legacy material sections
  part,                          -- document|summary|explanation|deep_explanation|examples|big_picture
  content, version, source_fingerprint?, provider?, model?, created_at
  UNIQUE (subject_id, material_id, part, version)

course_review_exclusions
  id, subject_id -> subjects ON DELETE CASCADE,
  material_id -> lesson_materials ON DELETE CASCADE,
  created_at
  UNIQUE (material_id)

reference_books
  id, title, author?, original_file_name, stored_file_name, page_count,
  created_at, updated_at

reference_book_subjects
  id, book_id -> reference_books ON DELETE CASCADE,
  subject_id -> subjects ON DELETE CASCADE, created_at
  UNIQUE (book_id, subject_id)

reference_book_chapters
  id, book_id -> reference_books ON DELETE CASCADE,
  title, level=0, start_page, end_page, sort_order,
  status='notStarted',           -- notStarted|reading|done
  created_at, updated_at

reference_book_ai_items
  id, book_id -> reference_books ON DELETE CASCADE,
  chapter_id? -> reference_book_chapters ON DELETE CASCADE,
  kind,                          -- brief|summary|explanation
  scope_key, start_page, end_page, content, version,
  provider?, model?, created_at
  UNIQUE (book_id, kind, scope_key, version)

reference_book_notes
  id, book_id -> reference_books ON DELETE CASCADE,
  page_number, title, content='', selected_text?,
  created_at, updated_at

reference_book_messages
  id, book_id -> reference_books ON DELETE CASCADE,
  role,                          -- user|assistant
  content, source_pages?,        -- JSON list of page numbers
  provider?, model?, created_at

reference_book_links
  id, book_id -> reference_books ON DELETE CASCADE,
  material_id -> lesson_materials ON DELETE CASCADE,
  start_page, end_page, priority, -- must|skim|optional
  reason?, done=false, created_at

reference_book_quizzes
  id, book_id -> reference_books ON DELETE CASCADE,
  chapter_id -> reference_book_chapters ON DELETE CASCADE,
  question_set_id -> question_sets ON DELETE CASCADE,
  created_at
  UNIQUE (question_set_id)

class_roadmap_entries
  id, class_id -> classes ON DELETE CASCADE,
  lesson_id -> lessons ON DELETE CASCADE,
  sort_order=0, note?, created_at, updated_at
  UNIQUE (class_id, lesson_id)

study_schedules
  id, lesson_id -> lessons ON DELETE CASCADE,
  paused=false, created_at, updated_at
  UNIQUE (lesson_id)

study_schedule_events
  id, lesson_id -> lessons ON DELETE CASCADE,
  kind,                          -- start|review|reschedule
  rating?,                       -- again|hard|good|easy
  recall_text?,
  event_on, due_on,              -- 'yyyy-MM-dd'
  interval_days, sequence_number, created_at
```

Device-local tables (raw SQL, excluded from Drift, sync, and the 39-table contract):

```text
local_book_pages (book_id, page, text) PK (book_id, page)
local_book_vectors (book_id, page, model, vector BLOB) PK (book_id, page)
local_book_state (
  book_id PK, stored_file_name, indexed_pages=0, page_count=0,
  last_page=1, vectors_model
)

local_ai_generation_jobs
  id TEXT PK, operation_kind, material_id, lesson_id?, title, file_path,
  material_type, provider, requested_model, resolved_model, thinking_mode?,
  endpoint_profile_id?, status, phase,
  progress_current=0, progress_total=0, attempt_count=0,
  partial_output?, checkpoint_json?, request_json, result_material_id?,
  error_message?, error_category?, parent_job_id?, superseded_by_job_id?,
  warning_message?, created_at, started_at?, updated_at, completed_at?
  -- never store provider keys or cloud session tokens

local_cloud_sync   -- single row id=1
  id INTEGER PK CHECK (id=1),
  account TEXT,                  -- binding so a library is not uploaded to the wrong account
  baseline TEXT NOT NULL DEFAULT '{}',
  pending TEXT,                  -- durable in-flight operation; retry the same operation id
  last_sync TEXT,
  backup_path TEXT
  -- never put session tokens here
```

`material_files` is not a local table. During sync it is a synthetic manifest: relative path → SHA-256 digest of an already-uploaded blob.

---

## Cloud sync

Server: `sync-server/`. PostgreSQL tables:

```text
accounts (id uuid, username unique, password_hash, created_at)
sessions (token_hash PK, account_id, device_name, expires_at, created_at)
changes (
  revision bigint identity PK,
  account_id, table_name, record_id, data jsonb,
  mutation_id uuid, request_hash,
  UNIQUE (account_id, mutation_id)
)
records (
  PK (account_id, table_name, record_id),
  revision -> changes, data jsonb
)
sync_commits (
  PK (account_id, operation_id),
  request_hash, response jsonb, created_at
)
files (
  PK (account_id, digest),
  digest CHECK 64 hex chars, bytes, created_at
)
```

Rules:

- Account-scoped rows. Immutable revision history. Explicit tombstones (`data` null). Mutation IDs make retries idempotent. Optimistic revision checks. A conflicting batch stays atomic — no partial apply.
- The Flutter client uses `/v2/snapshot` and `/v2/sync` only for library commits. One account-wide expected head and one durable operation id make the whole library commit atomic and retryable. Do not split related records into independent v1 batches.
- Every local library has its own `local_cloud_sync` row and secure-storage session key. The default library keeps `study_vault_cloud_session_v1`; other keys include the library account UUID.
- Limits: 20,000 metadata records, 48 MiB snapshot, files up to 256 MiB. Conflicts require an explicit user choice.
- A private file manifest must reference a blob that was already uploaded and SHA-256 verified. Do not serve the file directory publicly.
- File paths the manifest must include: `lessons/{lessonId}/{storedFileName}` and `books/{bookId}/{storedFileName}` (`cloudFilePath` in `cloud_sync_models.dart`).
- Login: `POST /v1/login`. Session is a bearer token, 30 days, stored by the client outside `local_cloud_sync`. `GET /v1/me`, logout, logout-all. `GET /healthz` returns `{ status, schemaVersion, syncProtocol: 2 }`.
- Production deploy is the dedicated `/opt/study-vault` Docker Compose project. Do not touch other VPS projects, their credentials, or their databases. Create each server username only with `npm run account -- create USERNAME` inside the API container; duplicate usernames are rejected. Backups are retained with no automatic deletion; the backup job refuses to start below 10 GiB free.

### Changing the database

1. Edit the Drift table in `lib/core/database/app_database.dart`.
2. Bump `schemaVersion` and add an `onUpgrade` step from the previous version.
3. Bump `kStudyVaultSchemaVersion` in `lib/core/backup/backup_providers.dart`.
4. Bump `schemaVersion` in `sync-server/src/store.js`.
5. Regenerate the contract: `flutter test --no-pub --dart-define=UPDATE_CLOUD_SCHEMA=true test/cloud_schema_contract_test.dart` and review `sync-server/src/library-schema.json`.
6. Update `tool/study_vault_mcp.py` `SCHEMA_VERSIONS` if the MCP tool must accept the new schema, then run `flutter test --no-pub test/study_vault_mcp_test.dart`.
7. If a new column has a default, add a PostgreSQL backfill in `sync-server/src/schema.sql` the same way `exam_date` and the material language columns were backfilled.
8. Do not turn `local_book_*`, `local_ai_generation_jobs`, or `local_cloud_sync` into Drift tables. Device-local table additions use `beforeOpen` creation and `_ensureLocalColumn` where required; they do not bump the synced Drift schema.

---

## MCP tools (`tool/study_vault_mcp.py`)

Registered as `study-vault`. Read tools return JSON. Write tools return a preview unless `apply: true`. Show the preview and wait for agreement before applying. The tool never deletes study content.

| Tool | Role |
| --- | --- |
| `library_overview` | Classes → subjects → lessons → materials and books, with ids |
| `get_lecture` | One material: AI versions, notes, flashcards, quizzes, course review, book links |
| `read_study_material` | Latest AI material of a type |
| `read_pdf_text` | Page text, at most 120 pages per call |
| `get_course_review` | Subject review status and optional content |
| `get_book` / `search_book` | Chapters, AI items, keyword page search |
| `add_lesson` / `attach_file` | Create a lesson; copy a local PDF, markdown/plain-text document, or image into `study_vault_files/lessons/`. Interactive HTML import is app-only |
| `draft_pdf_study_material` | Send one PDF to Gemini and return unsaved Markdown |
| `add_study_material` | Insert a new version; never replace |
| `add_flashcards` / `add_note` / `add_quiz` | Add study objects; duplicate flashcard fronts are skipped |
| `set_course_review_section` / `set_course_overview` | New course-review versions |
| `add_book_item` / `set_lecture_book_links` / `set_chapter_status` | Book AI text, lecture links, chapter status |

---

## Code map

```text
lib/app/                         app.dart, routes.dart
lib/core/database/               app_database.dart (+ .g.dart), database_provider.dart, built_in_data.dart
lib/core/storage/                study_vault_paths.dart, material_storage.dart
lib/core/backup/                 backup_service.dart, backup_archive.dart
lib/core/markdown/               study markdown, math, charts, code blocks, fence repair
lib/core/theme/                  app_theme.dart, app_colors.dart, app_spacing.dart
lib/core/widgets/                desktop_frame.dart, app_shell, empty states, grids
lib/core/navigation/shell_tab.dart
lib/core/text/search_text_normalizer.dart
lib/features/classes/
lib/features/subjects/
lib/features/lessons/            materials, PDF/image/text readers, lesson summary, progress
lib/features/class_roadmap/
lib/features/interactive_html/   HTML import, secure loopback serving, platform readers
lib/features/library_accounts/   isolated local libraries and active-library root
lib/features/study_pins/
lib/features/notes/
lib/features/favorites/
lib/features/search/
lib/features/study_review/
lib/features/study_schedule/     review_scheduler.dart is pure
lib/features/flashcards/
lib/features/study_workspace/
lib/features/ai_assistant/
lib/features/ai_chat/
lib/features/ai_generation_queue/ local raw-SQL queue, coordinator, Generation Center
lib/features/ai_questions/
lib/features/selection_ai/
lib/features/pdf_ai_materials/
lib/features/course_review/
lib/features/manual_entry/
lib/features/reference_books/
lib/features/cloud_account/      cloud_api.dart, cloud_sync_service.dart, cloud_sync_merge.dart, cloud_sync_schema.dart
lib/features/settings/
sync-server/src/                 app.js, store.js, library-sync.js, library-schema.json, schema.sql, account.js, security.js
sync-server/deploy/              backup.sh, renew-certificate.sh
file-share-server/               unauthenticated LAN tool — not the API
tool/study_vault_mcp.py
manual_entry_instruction.md
test/                            one file per behavior; see list below
```

Widget tests: Drift live streams hang under fake async time. Override stream providers with `Stream.value(...)` loaded via `tester.runAsync`.

---

## Checks to run

Flutter (no network pub get):

```text
flutter test --no-pub <touched test files>
flutter analyze
```

Install backend dependencies after lockfile/package changes:

```text
npm ci --prefix sync-server
```

After a schema or sync change also run:

```text
flutter test --no-pub test/cloud_schema_contract_test.dart test/cloud_sync_merge_test.dart test/cloud_sync_service_test.dart test/cloud_account_test.dart
```

Real HTTP round trip only when `TEST_DATABASE_URL` points at a disposable local Postgres:

```text
flutter test --no-pub test/cloud_sync_http_test.dart
npm test --prefix sync-server
```

Backend image check: `docker build -t study-vault-sync:verification sync-server`.

Other: `npm audit --omit=dev --prefix sync-server`, `bash -n sync-server/deploy/backup.sh sync-server/deploy/renew-certificate.sh`, `git diff --check`.

ARM64 sideload APK (debug signing, not a store release):

```text
flutter build apk --release --target-platform android-arm64 --split-per-abi --no-pub
```

Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

Feature tests already in `test/`: `library_accounts_test.dart`, `interactive_html_test.dart`, `ai_generation_queue_test.dart`, `ai_endpoint_profile_test.dart`, `ai_execution_selection_test.dart`, `lesson_summary_test.dart`, `course_review_test.dart`, `study_schedule_test.dart`, `study_schedule_screen_test.dart`, `pdf_ai_translation_test.dart`, `pdf_ai_translation_service_test.dart`, `pdf_ai_translation_reader_test.dart`, `reference_books_test.dart`, `chat_mentions_test.dart`, `study_vault_mcp_test.dart`, `desktop_layout_test.dart`, `cloud_schema_contract_test.dart`, plus the AI, quiz, pin, backup, material-variant, and markdown tests beside them.

---

## Invariants you must not break

- Schema version 23 stays consistent across Drift, `kStudyVaultSchemaVersion`, `store.js`, and `library-schema.json`.
- Sync commits are one atomic v2 operation. Conflicting batches do not partially apply.
- `local_book_pages`, `local_book_vectors`, `local_book_state`, `local_ai_generation_jobs`, and `local_cloud_sync` stay out of the synced schema.
- Session tokens never go in `local_cloud_sync`; AI queue rows never contain API keys. API keys and per-library cloud sessions stay in secure storage.
- Library account registry files, endpoint-profile metadata, HTML cache, HTML website state, and AI queue state remain device-local.
- Switching library accounts must dispose the old provider scope before mounting the new account’s scope. The default library keeps legacy paths and cannot be deleted.
- AI study materials, Course Review documents/legacy parts, annotation generations, and book AI items are versioned inserts. Do not update prior content rows in place.
- Study-schedule events are append-only. The current due date is the latest event.
- Schedule days and exam dates are `yyyy-MM-dd` text.
- The primary Course Review is `part=document` with null `material_id`. Legacy `examples`/`big_picture` also have null `material_id`; legacy material sections reference their source material.
- Interactive HTML syncs as a file but is never read as AI, Course Review, or chat context.
- Book search indexes stay on device. Ask-the-book receives retrieved pages (≤ 14), not the file.
- Persian PDF variants and Persian AI translations stay aligned to the source (page offset, or `<!-- sv-segment -->` sections).
- The MCP tool does not delete study content and does not write unless `apply` is true.
- `file-share-server` is never treated as the authenticated API.
- Tests do not open the user’s real `study_vault.sqlite`.

---

## Prompt templates

Copy one of these into Cursor in this repo. Replace the angle-bracket slots. Keep the constraints.

### Investigate before changing

```text
You are in the Study Vault repo. Do not change files. Answer from the code.

Question:
<what I need to know>

Look in:
<folders or globs>

Report file paths, the current behavior, storage values, and the test file that covers it. If it is not implemented, say so.
```

### Add a behavior inside an existing feature

```text
Add <behavior> to Study Vault.

Feature folder: lib/features/<feature>/
Follow the folder’s existing split (presentation / data / domain / services) and Riverpod providers already there.
Persist with the Drift tables named in docs/study-vault-assistant-brief.md. Do not add a table unless I explicitly ask for a schema change.
IDs are UUID text. Drift timestamps are unix seconds. Calendar days are yyyy-MM-dd text.
Rich text stays Quill Delta JSON plus a plain-text search column.
Do not sync device-local tables. Do not overwrite versioned AI rows; insert the next version.
Desktop: use AppSpacing.contentWidth and AdaptiveItemList when the screen is a list.
Tests: extend test/<existing_test>.dart. Use AppDatabase.forTesting(NativeDatabase.memory()). In widget tests, override Drift streams with Stream.value loaded via tester.runAsync.
Run: flutter test --no-pub test/<existing_test>.dart && flutter analyze
Do not commit.
```

### Change the database

```text
Change the Study Vault schema: <exact column or table change>.

1. Edit lib/core/database/app_database.dart.
2. Bump schemaVersion from 24 and add an onUpgrade step only.
3. Bump kStudyVaultSchemaVersion in lib/core/backup/backup_providers.dart.
4. Bump schemaVersion in sync-server/src/store.js.
5. Regenerate sync-server/src/library-schema.json with:
   flutter test --no-pub --dart-define=UPDATE_CLOUD_SCHEMA=true test/cloud_schema_contract_test.dart
6. If old server rows need the new field, backfill in sync-server/src/schema.sql.
7. If tool/study_vault_mcp.py reads or writes the table, bump SCHEMA_VERSIONS and update the tool.
8. Leave local_book_*, local_ai_generation_jobs, and local_cloud_sync as raw SQL, not Drift tables.

Run:
flutter test --no-pub test/cloud_schema_contract_test.dart test/database_test.dart test/study_vault_mcp_test.dart
flutter analyze
Do not commit. Show me the contract diff.
```

### Fix a bug without widening the change

```text
Bug: <what the user sees>.

Find the smallest cause in <likely files>. Fix that cause only.
Keep storage values, foreign keys, and sync behavior as they are.
Add or extend a test that failed before the fix and passes after.
Run flutter test --no-pub on that test file and flutter analyze.
Do not commit. Tell me the cause in two sentences.
```

### Course Review or PDF AI material

```text
Change <course review or pdf ai material behavior>.

Rules already in the app:
- pdf_ai_materials types: summary, explanation, deep_explanation, real_world_examples, slideshow.
- New output is a new version row. Unique (material_id, type, version). source_fingerprint marks staleness.
- PDF, markdown, and plain text are documents. Interactive HTML and images are not document AI sources.
- Long-running generation and Persian translation use local_ai_generation_jobs through AiGenerationCoordinator. Jobs capture provider/model/profile but never keys. Maximum concurrency is 2.
- Persian translations are one row per source version + language fa, section-aligned with <!-- sv-segment -->, placeholders ⟦SVn⟧ for code, formulas, charts, and slides. source_hash marks stale translations. Code and notation render LTR.
- The primary Course Review is one complete Markdown document per subject: part=document, material_id null, and every save appends a version.
- Older per-material summary/explanation/deep_explanation and subject-wide examples/big_picture rows remain readable and compilable but are not the main editor.
- Document staleness is based on every included document and its current source fingerprint.
- Exclusions are course_review_exclusions, unique on material_id.
- Complete-document external wording comes from CourseReviewPrompts.completeReviewPrompt.
- JSON import key course_review still writes legacy section rows and follows manual_entry_instruction.md.

Tests: test/course_review_test.dart, test/ai_generation_queue_test.dart when queue behavior changes, and the pdf_ai_translation_* tests if translation is touched.
Run those tests with flutter test --no-pub and flutter analyze.
Do not commit.
```

### AI generation queue or endpoint profiles

```text
Change <AI queue or endpoint-profile behavior>.

Keep local_ai_generation_jobs a raw device-local table created in beforeOpen. Do not add it to Drift, cloud schema, or backups-by-table.
Jobs are FIFO with at most 2 running. Store AiExecutionSelection identity (provider, requested/resolved model, endpoint profile, thinking mode), never an API key.
Partial output stays on the job until explicitly saved. Restarted running jobs become partial or interrupted.
Deleting a profile marks its unfinished jobs configuration_required; never silently route them to another profile.
Endpoint metadata stays in SharedPreferences. Endpoint keys stay in flutter_secure_storage. Profiles and keys never sync.
Do not claim OS notifications; this build has in-app notices only.

Tests: test/ai_generation_queue_test.dart, test/ai_endpoint_profile_test.dart, and test/ai_execution_selection_test.dart as applicable.
Run touched tests with flutter test --no-pub and run flutter analyze.
Do not commit.
```

### Interactive HTML

```text
Change Interactive HTML: <change>.

Feature folder: lib/features/interactive_html/.
MIME types are text/html for one page and application/vnd.study-vault.html-bundle+zip for a zip bundle with index.html.
HTML is an ordinary lesson_materials row and syncs through material_files, but it is not a document source for AI Study Materials, Course Review, or chat context.
Serve only the unpacked material folder from loopback with a per-open path token. Preserve stable per-item origin behavior for localStorage.
Reject zip-slip, more than 5000 entries, more than 512 MiB unpacked, and imports above the 256 MiB file limit.
Website state, temp cache, and study_vault_html_webdata stay device-local.
Keep the platform matrix and browser fallbacks intact.

Tests: test/interactive_html_test.dart.
Run that test with flutter test --no-pub and run flutter analyze.
Do not commit.
```

### Library accounts

```text
Change local library accounts: <change>.

Feature folder: lib/features/library_accounts/.
Each library owns its database, study_vault_files, backup metadata, sync recovery, AI queue, and secure cloud session.
The default library (initially Personal) stays in the legacy documents-root paths and cannot be deleted. Other libraries live under study_vault_accounts/{uuid}/.
LibraryAccountsController selects the new StudyVaultPaths root; LibraryAccountsRoot inserts a switching frame that disposes the old ProviderScope before mounting the new scope. Never keep the old database, sync service, or queue alive across a switch.
Registry files are device-local and never synchronized. Cloud secure-storage keys are per library; preserve the default library’s legacy key.
Deleting a non-default library is permanent and recursive, so retain explicit confirmation and never delete the active library before switching away.

Tests: test/library_accounts_test.dart plus cloud/backup tests when those boundaries change.
Run touched tests with flutter test --no-pub and run flutter analyze.
Do not commit.
```

### Study schedule

```text
Change Study Schedule: <change>.

Keep ReviewScheduler pure in lib/features/study_schedule/domain/review_scheduler.dart.
Ladder 1/3/7/21/60/120/240/365. Easy skips a rung. Hard ×1.2. Again → 1 day.
Late success uses the real gap. Early success must not pull due_on earlier.
Exam cap is 40% of days left before subjects.exam_date.
Enroll only from setLessonProgress when status becomes reviewed or mastered. Opening a lesson must not enroll.
study_schedules stays one minimal row per lesson. Due date lives only on the latest study_schedule_events row. Events are append-only.
Days are yyyy-MM-dd text. A ≥60-day success marks the lesson mastered. Again marks it reviewed.
Daily limit stays in SharedPreferences.
Tests: test/study_schedule_test.dart and test/study_schedule_screen_test.dart.
Do not commit.
```

### Reference books

```text
Change reference books: <change>.

Synced tables only: reference_books, reference_book_subjects, reference_book_chapters, reference_book_ai_items, reference_book_notes, reference_book_messages, reference_book_links, reference_book_quizzes.
Files: study_vault_files/books/{bookId}/{storedFileName}, and cloudFilePath must keep requiring that manifest.
Do not make local_book_pages, local_book_vectors, or local_book_state into Drift tables.
Search stays BM25 in BookTextIndex, fused with cosine when vectors exist.
AI requests receive at most 14 retrieved pages. Long chapters are chunk-digested first.
Book AI items are versioned per (book_id, kind, scope_key). Links use priority must|skim|optional.
Tests: test/reference_books_test.dart.
Do not commit.
```

### Sync or backup

```text
Change cloud sync or backup: <change>.

Client commits go through /v2/snapshot and /v2/sync with one expected head and one durable operation id. Do not split related rows into v1 batches.
Rows are account-scoped. History is immutable. Tombstones are explicit. Mutation ids retry safely. A conflict fails the whole batch.
local_cloud_sync stores baseline, pending operation, account binding, last sync, and backup path. Never store a session token there.
material_files entries must point at a blob already uploaded and SHA-256 checked.
Limits stay 20,000 metadata records, 48 MiB snapshot, 256 MiB per file.
Tests: test/cloud_schema_contract_test.dart test/cloud_sync_merge_test.dart test/cloud_sync_service_test.dart test/cloud_account_test.dart.
Do not point tests at a production database. Do not commit.
```
