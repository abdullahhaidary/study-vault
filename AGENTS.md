# Study Vault project checks

- Flutter verification: `flutter test --no-pub`; target individual files for isolated changes. Run `flutter analyze` for Dart changes.
- POCO/ARM64 test APK: `flutter build apk --release --target-platform android-arm64 --split-per-abi --no-pub`. Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. The current Android release configuration uses the debug signing key, so this is a sideload/testing artifact, not a production-store release.
- The desktop app stores SQLite and material files through `StudyVaultPaths`; do not change a live database while testing. Use `AppDatabase.forTesting(NativeDatabase.memory())`.
- `file-share-server/` is a separate unauthenticated LAN sharing tool, not the private cloud backend. Do not publish it as the authenticated API.
- `sync-server/` is the private Node/PostgreSQL backend. Production uses Node 24; its Dockerfile pins the runtime image.
- Install backend dependencies with `npm ci --prefix sync-server`.
- Backend integration tests: set `TEST_DATABASE_URL` to an isolated disposable PostgreSQL database, then run `npm test --prefix sync-server`. Tests create synthetic accounts and records; never target production.
- Build the backend with `docker build -t study-vault-sync:verification sync-server`.
- Additional checks: `npm audit --omit=dev --prefix sync-server`, `bash -n sync-server/deploy/backup.sh sync-server/deploy/renew-certificate.sh`, and `git diff --check`.
- Backend sync uses schema version 16, account-scoped rows, immutable revision history, explicit tombstones, mutation IDs for retries, and optimistic revision checks. Conflicting batches must remain atomic.
- Private file manifests must reference an already-uploaded SHA-256-verified blob. Do not serve the file directory publicly.
- Production deployment uses the dedicated `/opt/study-vault` Docker Compose project. Do not alter other VPS projects, their credentials, or their databases.
- Keep database secrets and TLS private keys out of source control and terminal output. Provision the app account with the interactive `npm run account -- create USERNAME` command inside the API container.
- Server-side backups are retained without automatic deletion. The backup job refuses to start below 10 GiB free; arrange off-server backup storage separately.
