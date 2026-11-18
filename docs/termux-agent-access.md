# Termux agent access

StudyDesk exposes an optional local bridge for an MCP client running inside
Termux on the **same Android phone**. It uses the active library directly:
no PC, root access, cloud account, or sync is required. Termux never opens the
app's private database. Changes use the same app database, codecs, versioning,
and file locations as changes made in the UI, and can later sync normally.

## Setup

1. Install the updated Android APK and open the intended StudyDesk library.
2. Open **Settings → Advanced Settings → Termux agent access**. Enable **Allow agents to save
   changes** if desired, then tap **Start agent access**.
3. In Termux run `pkg install python curl`.
4. In StudyDesk tap **Copy Termux setup**, paste it into Termux, and run it.
   This downloads a session-configured, standard-library-only Python adapter
   from the app to `~/.local/share/study-vault/mcp.py`, with file mode `600`.
5. Tap **Copy MCP configuration** and merge its `study-vault` server entry into
   the MCP configuration of the agent running in Termux. Restart/reconnect its
   MCP server. The client must support local stdio MCP servers; its configuration
   file location depends on the client.

The copied configuration has this shape:

```json
{
  "mcpServers": {
    "study-vault": {
      "command": "sh",
      "args": ["-c", "exec python \"$HOME/.local/share/study-vault/mcp.py\""]
    }
  }
}
```

For example, ask the agent:

> Search my Physics subject for inertia, read the matching lecture, and preview
> a note plus ten flashcards for that lesson.

## Available operations

- `library_overview`, `search_library`: discover IDs and search globally or by
  class, subject, or lesson. `index_files=true` refreshes searchable local file
  text; it can take time for large libraries. Indexed books are also searchable.
- `get_lesson`, `get_book`, `read_note`, `get_quiz`, `get_course_review`,
  `read_study_material`: read saved content. Collections support `offset` and
  `limit` (default 20, maximum 100). Large results require smaller pages.
- `read_pdf_text`: extract a range of at most 120 pages on the phone. Scanned
  PDFs without text need OCR in another tool.
- `get_file`: download an original lecture file or book PDF to a private cache
  directory inside Termux; returns its local path for the agent's own tools.
- `add_lesson`, `attach_file`, `add_note`, `add_flashcards`, `add_quiz`: create
  content. Attachment paths refer to files **inside Termux**, not app-private
  paths. PDF, image, Markdown, and text attachments are supported, up to 256 MiB.
- `add_study_material`, `set_course_review_document`, `add_book_item`: append
  versions of generated study content, preserving existing versions.
- `set_chapter_status`: update book reading progress.

Writes preview by default. Agents should show the preview and use `apply: true`
only with user authorization. The app must also have allowed writes when the
session was started. There are no deletion, raw SQL, credential, shell-execution,
or cloud administration tools. The bridge does not call an AI provider itself:
the connected agent reads sources, generates content, and saves it through tools.

## Session and Android behavior

The bridge binds only to `127.0.0.1` on a randomly assigned port, requires a
random bearer key, rejects browser origins and untrusted Host headers, and never
serves a public file directory. The setup command and downloaded adapter contain
the session key: keep them private. The adapter bypasses proxies and refuses
redirects. Staged uploads and responses are bounded; recent successful writes
have session-local request-ID replay protection. The adapter never automatically
retries a write after a network error: inspect the library before repeating it.

Access stops when explicitly stopped, after eight hours, on account-scope
disposal/library switching, before backup restoration, or when the app process
exits. Start again and rerun the **new** setup command to update the port/key;
the MCP configuration itself stays the same. Sessions are not persisted or synced.

An Android foreground service helps keep the app process available while working
in Termux. Allow its notification, keep StudyDesk in recent apps, and allow
background activity if the phone's battery manager interrupts it. This does not
guarantee operation after a force-stop, process kill, or reboot. No automatic
restart or boot service is installed.

## Development verification

```sh
flutter test --no-pub test/agent_bridge_test.dart test/study_vault_mcp_test.dart test/cloud_schema_contract_test.dart test/backup_restore_paths_test.dart test/library_accounts_test.dart
flutter analyze
flutter build apk --release --target-platform android-arm64 --split-per-abi --no-pub
```

Tests use an isolated memory database and temporary files, including a real
Python-stdio → loopback HTTP → Dart/Drift round trip. The desktop
`tool/study_vault_mcp.py` remains a separate direct-SQLite adapter.
