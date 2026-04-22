# PunchCard

A Swift CLI tool for tracking contract work hours, capturing billable expenses, and generating PDF invoices. Designed to integrate with [Claude Code](https://claude.ai/claude-code) via slash commands (`/punch-in`, `/punch-out`, `/invoice`, `/expense`).

## Features

- **Time tracking** -- start/stop sessions, log notes mid-session
- **Expense tracking** -- `punchcard expense add` posts a billable expense (optionally with a receipt image) directly to your Google Sheet; the mobile app captures receipts from your phone
- **Project management** -- register project names, validate on start
- **PDF invoices** -- hours, expenses, or both, with a dedicated `--expenses-only` mode
- **CSV export** -- portable backup for accounting and spreadsheets
- **Edit/delete/undelete** -- fix mistakes with soft-delete (nothing is ever truly lost)
- **Google Sheet sync** -- push sessions and expenses to a Sheet via Apps Script, pull billable expenses back for invoices
- **Mobile companion** -- pair a project via terminal QR; capture receipts and log sessions from iOS/Android
- **Claude Code skills** -- AI-driven workflows via `/punch-in`, `/punch-out`, `/invoice`, `/expense`

## Installation

```bash
git clone https://github.com/zacspa/PunchCard.git
cd PunchCard
swift build -c release
mkdir -p ~/.local/bin
ln -sf $(pwd)/.build/release/punchcard ~/.local/bin/punchcard
```

### Claude Code skills (optional)

Make `/punch-in`, `/punch-out`, `/invoice`, and `/expense` available in Claude Code by symlinking the skills into `~/.claude/commands/`:

```bash
./skills/install.sh
```

The installer symlinks (not copies) so edits to `skills/*.md` take effect immediately. Re-run any time you add or remove a skill.

## Quick start

```bash
# Register a project
punchcard project add "Acme Corp"

# Start tracking (right now)
punchcard start --project "Acme Corp"

# Or backdate the start — I forgot to punch in earlier
punchcard start --project "Acme Corp" --at "9:15am"
punchcard start --project "Acme Corp" --ago 30m
punchcard start --project "Acme Corp" --at "2026-04-18 09:00"

# Log notes during work
punchcard log "Fixed authentication bug"
punchcard log "Added unit tests"

# Check status
punchcard status

# Stop tracking (with a summary)
punchcard stop --summary "Implemented JWT auth and added login/signup endpoints"

# View sessions
punchcard list
punchcard list --from 2026-03-01 --to 2026-03-31 --project "Acme Corp"

# Generate an invoice
punchcard invoice --from 2026-03-01 --to 2026-03-31 --rate 150 --name "Your Name" --client "Acme Corp"

# Include billable expenses pulled from the Google Sheet
punchcard invoice --from 2026-03-01 --to 2026-03-31 --rate 150 --name "Your Name" --client "Acme Corp" --with-expenses

# Expenses-only invoice (no hours; --rate not required)
punchcard invoice --from 2026-03-01 --to 2026-03-31 --name "Your Name" --client "Acme Corp" --expenses-only

# Log a billable expense (posts to the sheet immediately)
punchcard expense add --project "Acme Corp" --merchant "Café Grumpy" --amount 14.20 --category meals --image ~/Pictures/receipt.jpg

# Export to CSV
punchcard export --output ~/invoices/march-2026.csv
```

## Commands

| Command | Description |
|---|---|
| `start --project NAME` | Start a work session |
| `start --at "9:15am"` | Backdate the start to a time today (also accepts ISO 8601 and `yyyy-MM-dd HH:mm`) |
| `start --ago 30m` | Backdate the start by a relative duration (`30m`, `1h`, `1h30m`) |
| `stop --summary TEXT` | Stop session with a summary |
| `stop --summary-file PATH` | Stop session with summary from a file (avoids shell escaping) |
| `stop --no-sync` | Stop without pushing to the configured Google Sheet |
| `sync` | Push all completed sessions to the configured sheet (supports `--from`/`--to`/`--project`) |
| `config show` | Inspect sync configuration |
| `config set-webhook URL` | Point sync at a Google Apps Script / HTTP webhook |
| `config set-secret SECRET` | Optional shared secret sent as `X-PunchCard-Secret` |
| `config enable` / `config disable` | Toggle sync without deleting the URL |
| `config qr PROJECT` | Print a QR code to pair a project with the mobile app |
| `expense add` | Log a billable expense (merchant, amount, date, category, optional receipt image); posts to the sheet |
| `log "NOTE"` | Add a note to the active session |
| `status` | Show active session info |
| `list` | List completed sessions |
| `list --show-ids` | List sessions with UUIDs (for edit/delete) |
| `edit --id UUID` | Edit a session (`--project`, `--summary`, `--end-time`) |
| `delete --id UUID` | Soft-delete a session |
| `undelete --id UUID` | Restore a soft-deleted session |
| `export` | Export sessions to CSV |
| `invoice` | Generate a PDF invoice (add `--with-expenses` to pull billable expenses from the sheet, or `--expenses-only` for an expenses-only invoice with no hours) |
| `project add/list/remove` | Manage registered project names |

## Claude Code integration

With the skills installed, you can use natural language commands in Claude Code:

- **`/punch-in Acme Corp`** -- starts tracking, checks for active sessions
- **`/punch-out`** -- Claude summarizes the session from conversation context, captures git commits, and stops tracking
- **`/invoice last two weeks at $150/hr for Acme Corp`** -- Claude converts natural language dates, previews sessions, and generates a PDF
- **`/expense`** (drop a receipt image into the prompt) -- Claude reads the receipt with vision, extracts merchant/amount/date/category, confirms with you, then runs `punchcard expense add` with the receipt attached

## Google Sheet sync (optional)

PunchCard can POST each completed session to a webhook. The easiest target is a Google Apps Script bound to a Sheet, deployed as a web app.

### 1. Create the sheet and script

In a new Google Sheet, go to **Extensions → Apps Script** and paste the following. The script **fails closed** if you leave `SHARED_SECRET` empty — you must set it to a random value and use the same value via `punchcard config set-secret`.

```javascript
// Generate with e.g. `openssl rand -hex 32`.
// MUST be non-empty — the script refuses all requests otherwise.
const SHARED_SECRET = "";
const SHEET_NAME = "Sessions";
const HEADERS = ["ID", "Project", "Start", "End", "Hours", "Summary",
                 "Notes", "Commits", "Deleted", "LastSyncedAt"];

function doPost(e) {
  // Constant-time secret comparison via the X-PunchCard-Secret header only.
  if (!SHARED_SECRET) return json_({ok: false, error: "server not configured"}, 500);
  const provided = (e.parameter && e.parameter.secret) || "";
  const headerSecret = e.postData && e.postData.contents
    ? (getHeader_(e, "X-PunchCard-Secret") || provided) : "";
  if (!constantTimeEquals_(headerSecret, SHARED_SECRET)) {
    return json_({ok: false, error: "forbidden"}, 403);
  }

  // Serialize concurrent stop/sync calls.
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const body = JSON.parse(e.postData.contents);
    const sheet = ensureSheet_();
    const action = body.action || "upsert";
    const sessions = (body.sessions || []);
    const scope = body.scope || null;

    // Build a single id→rowIndex map so upsert is O(sessions + rows), not O(n·m).
    const data = sheet.getDataRange().getValues();
    const idToRow = {};
    for (let r = 1; r < data.length; r++) idToRow[data[r][0]] = r + 1;

    let deleted = 0;
    if (action === "replace" && scope) {
      // Scoped replace: drop every row matching the filter (regardless of
      // whether it's in the payload), then the loop below upserts.
      for (let r = data.length - 1; r >= 1; r--) {
        if (matchesScope_(data[r], scope)) {
          sheet.deleteRow(r + 1);
          deleted++;
        }
      }
      // Rebuild map after deletes.
      const after = sheet.getDataRange().getValues();
      for (const k of Object.keys(idToRow)) delete idToRow[k];
      for (let r = 1; r < after.length; r++) idToRow[after[r][0]] = r + 1;
    }

    let upserted = 0;
    const now = new Date().toISOString();
    for (const s of sessions) {
      const row = [s.id, s.project, s.startTime, s.endTime || "", s.hours || 0,
                   s.summary || "", (s.notes || []).join("; "),
                   (s.commits || []).join("; "), s.deleted ? "yes" : "", now];
      const existing = idToRow[s.id];
      if (existing) {
        sheet.getRange(existing, 1, 1, row.length).setValues([row]);
      } else {
        sheet.appendRow(row);
        idToRow[s.id] = sheet.getLastRow();
      }
      upserted++;
    }

    return json_({ok: true, upserted: upserted, deleted: deleted}, 200);
  } catch (err) {
    return json_({ok: false, error: String(err)}, 500);
  } finally {
    lock.releaseLock();
  }
}

function ensureSheet_() {
  const ss = SpreadsheetApp.getActive();
  let sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_NAME);
    sheet.appendRow(HEADERS);
    sheet.setFrozenRows(1);
  }
  return sheet;
}

function matchesScope_(row, scope) {
  // row columns: [id, project, startISO, endISO, hours, summary, notes, commits, deleted, syncedAt]
  const startIso = row[2];
  if (!startIso) return false;
  const start = new Date(startIso);
  if (scope.from && start < new Date(scope.from + "T00:00:00Z")) return false;
  if (scope.to) {
    const endOfDay = new Date(scope.to + "T00:00:00Z");
    endOfDay.setUTCDate(endOfDay.getUTCDate() + 1);
    if (start >= endOfDay) return false;
  }
  if (scope.project && row[1] !== scope.project) return false;
  if (!scope.includeDeleted && row[8] === "yes") return false;
  return true;
}

function getHeader_(e, name) {
  // Apps Script exposes request headers on `e.headers` for some deployments,
  // but most do not. Prefer the header; fall back is handled by caller.
  try {
    if (e && e.headers) {
      const lower = name.toLowerCase();
      for (const k of Object.keys(e.headers)) {
        if (k.toLowerCase() === lower) return e.headers[k];
      }
    }
  } catch (_) {}
  return null;
}

function constantTimeEquals_(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return mismatch === 0;
}

function json_(obj, status) {
  return ContentService.createTextOutput(JSON.stringify(obj))
                       .setMimeType(ContentService.MimeType.JSON);
}
```

> **Note on header auth.** Apps Script web apps don't reliably expose custom request headers, so PunchCard also sends the secret as a URL `?secret=...` query parameter as a fallback — the Apps Script checks header-then-query. Always keep the webhook URL private regardless.

### 1b. (Optional) Expense sync — add the expenses handler

To also receive expenses from the mobile app or `punchcard expense add`, paste `apps-script/Expenses.gs` from this repo into the same script project as a second file, and route the new action in your `doPost`:

```javascript
// inside doPost, after the secret check, before the session logic:
const body = JSON.parse(e.postData.contents);
if (body.action === 'upsert-expenses') {
  return PunchCardExpenses.handle(body);
}
```

To let `punchcard invoice --with-expenses` / `--expenses-only` pull billable expenses back from the sheet, also add a matching `doGet`:

```javascript
function doGet(e) {
  // same secret guard as doPost
  if (e.parameter.resource === 'expenses') {
    return PunchCardExpenses.list(e.parameter);
  }
  return ContentService
    .createTextOutput(JSON.stringify({ ok: false, error: 'Unknown resource' }))
    .setMimeType(ContentService.MimeType.JSON);
}
```

On first use, the handler creates an `Expenses` sheet tab and a `PunchCard Receipts` Drive folder. The script project will prompt for Drive permissions the first time it uploads a receipt — grant both read + write and redeploy the Web App (Deploy → Manage deployments → edit → New version) so the new scopes take effect. Full details in `apps-script/README.md`.

### 2. Deploy as a web app

Click **Deploy → New deployment → Web app**. Set "Execute as: Me" and "Who has access: Anyone with the link". Copy the deployment URL. The URL is a bearer capability — treat it like a secret.

### 3. Point PunchCard at it

```bash
# Webhook URL (positional) or --stdin to avoid shell-history leakage
punchcard config set-webhook --stdin

# Shared secret: with no argument, prompts with echo off
punchcard config set-secret
```

From then on, every `punchcard stop`, `edit`, `delete`, and `undelete` pushes to the sheet (sub-7-second timeout; failures queue locally). Pass `--no-sync` to skip for a single invocation, or `punchcard config disable` to pause entirely.

To backfill history, flush queued failures, or reconcile after edits:

```bash
punchcard sync                                       # upsert every completed session
punchcard sync --from 2026-04-01 --to 2026-04-30     # scoped range
punchcard sync --from 2026-04-01 --to 2026-04-30 --replace
                                                     # delete all rows in scope on the sheet, then append
punchcard sync --flush-queue                         # retry sessions that failed earlier
```

The webhook URL and shared secret live in `~/.punchcard/sync.json` (mode 0600). `punchcard config show` redacts the URL by default — pass `--reveal` to print it in full.

## Mobile companion (optional)

An Expo/React Native app in `mobile/` logs sessions and captures receipts from your phone and syncs to the same Google Sheet. Each project keeps its own webhook URL and shared secret on-device; pairing is done with a QR code from the CLI:

```bash
punchcard config qr "Acme Corp"   # prints a QR in your terminal
```

On the phone: PunchCard mobile → Settings → Scan project QR. The QR embeds the webhook URL and secret for that project — don't screenshot or share it. See `mobile/DESIGN_BRIEF.md` for the app architecture.

## Data storage

All data is stored in `~/.punchcard/`:

| File | Purpose |
|---|---|
| `sessions.json` | All session data (including soft-deleted) |
| `sessions.json.bak` | Auto-backup of previous state |
| `projects.json` | Registered project names |
| `sync.json` | Google Sheet webhook config (chmod 600; contains URL + optional secret) |
| `invoice-counter.txt` | Auto-incrementing invoice number |
| `invoices/` | Generated PDF invoices |

## Testing

```bash
swift test
```

112 tests across 17 suites covering models, stores, PDF generation (with text extraction), CSV export, edit/delete/undelete, file locking, backup, and integration workflows.

## Requirements

- macOS 13+
- Swift 6.0+
