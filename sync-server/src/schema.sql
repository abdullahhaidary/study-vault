CREATE TABLE IF NOT EXISTS accounts (
  id uuid PRIMARY KEY,
  username text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS sessions (
  token_hash text PRIMARY KEY,
  account_id uuid NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  device_name text NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sessions_account ON sessions(account_id);
CREATE TABLE IF NOT EXISTS changes (
  revision bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  account_id uuid NOT NULL REFERENCES accounts(id),
  table_name text NOT NULL,
  record_id text NOT NULL,
  data jsonb,
  mutation_id uuid NOT NULL,
  request_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(account_id, mutation_id)
);
CREATE INDEX IF NOT EXISTS changes_account_revision ON changes(account_id, revision);
CREATE TABLE IF NOT EXISTS records (
  account_id uuid NOT NULL REFERENCES accounts(id),
  table_name text NOT NULL,
  record_id text NOT NULL,
  revision bigint NOT NULL REFERENCES changes(revision),
  data jsonb,
  PRIMARY KEY(account_id, table_name, record_id)
);
CREATE TABLE IF NOT EXISTS sync_commits (
  account_id uuid NOT NULL REFERENCES accounts(id),
  operation_id uuid NOT NULL,
  request_hash text NOT NULL,
  response jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(account_id, operation_id)
);
CREATE TABLE IF NOT EXISTS files (
  account_id uuid NOT NULL REFERENCES accounts(id),
  digest text NOT NULL CHECK(digest ~ '^[a-f0-9]{64}$'),
  bytes bigint NOT NULL CHECK(bytes >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(account_id, digest)
);
