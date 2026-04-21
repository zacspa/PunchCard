import { drizzle } from "drizzle-orm/expo-sqlite";
import { openDatabaseSync } from "expo-sqlite";

const sqlite = openDatabaseSync("punchcard.db");

sqlite.execSync(`
  CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    project TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT,
    notes TEXT NOT NULL DEFAULT '[]',
    summary TEXT,
    commits TEXT NOT NULL DEFAULT '[]',
    deleted INTEGER NOT NULL DEFAULT 0,
    deleted_at TEXT
  );
  CREATE INDEX IF NOT EXISTS sessions_active_idx
    ON sessions (end_time) WHERE end_time IS NULL AND deleted = 0;
  CREATE INDEX IF NOT EXISTS sessions_start_idx
    ON sessions (start_time DESC) WHERE deleted = 0;
  CREATE INDEX IF NOT EXISTS sessions_end_idx
    ON sessions (end_time DESC) WHERE end_time IS NOT NULL AND deleted = 0;

  CREATE TABLE IF NOT EXISTS projects (
    name TEXT PRIMARY KEY,
    webhook_url TEXT,
    sync_enabled INTEGER NOT NULL DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS sync_queue (
    session_id TEXT PRIMARY KEY,
    enqueued_at TEXT NOT NULL,
    last_error TEXT
  );

  CREATE TABLE IF NOT EXISTS expenses (
    id TEXT PRIMARY KEY,
    project TEXT NOT NULL,
    merchant TEXT NOT NULL DEFAULT '',
    amount_cents INTEGER NOT NULL DEFAULT 0,
    currency TEXT NOT NULL DEFAULT 'USD',
    captured_at TEXT NOT NULL,
    category TEXT,
    billable INTEGER NOT NULL DEFAULT 1,
    note TEXT,
    receipt_image_path TEXT,
    ocr TEXT,
    sync_state TEXT NOT NULL DEFAULT 'local',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
  );
  CREATE INDEX IF NOT EXISTS expenses_captured_idx
    ON expenses (captured_at DESC) WHERE deleted = 0;
  CREATE INDEX IF NOT EXISTS expenses_project_idx
    ON expenses (project) WHERE deleted = 0;

  CREATE TABLE IF NOT EXISTS expense_sync_queue (
    expense_id TEXT PRIMARY KEY,
    enqueued_at TEXT NOT NULL,
    last_error TEXT
  );
`);

// Backfill columns if upgrading from a schema that predated per-project sync.
type ColumnInfo = { name: string };
const projectCols = sqlite.getAllSync<ColumnInfo>("PRAGMA table_info(projects);");
const has = (col: string) => projectCols.some((c) => c.name === col);
if (!has("webhook_url")) {
  sqlite.execSync("ALTER TABLE projects ADD COLUMN webhook_url TEXT;");
}
if (!has("sync_enabled")) {
  sqlite.execSync("ALTER TABLE projects ADD COLUMN sync_enabled INTEGER NOT NULL DEFAULT 0;");
}

export const db = drizzle(sqlite);
