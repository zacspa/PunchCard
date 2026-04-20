# PunchCard

A Swift CLI tool for tracking contract work hours and generating PDF invoices. Designed to integrate with [Claude Code](https://claude.ai/claude-code) via slash commands (`/punch-in`, `/punch-out`, `/invoice`).

## Features

- **Time tracking** -- start/stop sessions, log notes mid-session
- **Project management** -- register project names, validate on start
- **PDF invoices** -- professional layout with line items, rates, totals, and invoice numbering
- **CSV export** -- portable backup for accounting and spreadsheets
- **Edit/delete/undelete** -- fix mistakes with soft-delete (nothing is ever truly lost)
- **File locking** -- safe against concurrent CLI invocations
- **Auto-backup** -- `sessions.json.bak` created on every write
- **Claude Code skills** -- AI-driven time tracking via `/punch-in`, `/punch-out`, `/invoice`

## Installation

```bash
git clone https://github.com/zacspa/PunchCard.git
cd PunchCard
swift build -c release
mkdir -p ~/.local/bin
ln -sf $(pwd)/.build/release/punchcard ~/.local/bin/punchcard
```

### Claude Code skills (optional)

Copy the skill files to make `/punch-in`, `/punch-out`, and `/invoice` available in Claude Code:

```bash
mkdir -p ~/.claude/commands
cp skills/punch-in.md ~/.claude/commands/
cp skills/punch-out.md ~/.claude/commands/
cp skills/invoice.md ~/.claude/commands/
```

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
| `log "NOTE"` | Add a note to the active session |
| `status` | Show active session info |
| `list` | List completed sessions |
| `list --show-ids` | List sessions with UUIDs (for edit/delete) |
| `edit --id UUID` | Edit a session (`--project`, `--summary`, `--end-time`) |
| `delete --id UUID` | Soft-delete a session |
| `undelete --id UUID` | Restore a soft-deleted session |
| `export` | Export sessions to CSV |
| `invoice` | Generate a PDF invoice |
| `project add/list/remove` | Manage registered project names |

## Claude Code integration

With the skills installed, you can use natural language commands in Claude Code:

- **`/punch-in Acme Corp`** -- starts tracking, checks for active sessions
- **`/punch-out`** -- Claude summarizes the session from conversation context, captures git commits, and stops tracking
- **`/invoice last two weeks at $150/hr for Acme Corp`** -- Claude converts natural language dates, previews sessions, and generates a PDF

## Google Sheet sync (optional)

PunchCard can POST each completed session to a webhook. The easiest target is a Google Apps Script bound to a Sheet, deployed as a web app.

### 1. Create the sheet and script

In a new Google Sheet, go to **Extensions → Apps Script** and paste:

```javascript
const SHEET_NAME = "Sessions";
const HEADERS = ["ID", "Project", "Start", "End", "Hours", "Summary", "Notes", "Commits", "Deleted"];
const SHARED_SECRET = ""; // set this and keep it in sync with `punchcard config set-secret`

function doPost(e) {
  const body = JSON.parse(e.postData.contents);
  if (SHARED_SECRET && body.secret !== SHARED_SECRET) {
    return ContentService.createTextOutput("forbidden").setMimeType(ContentService.MimeType.TEXT);
  }

  const ss = SpreadsheetApp.getActive();
  let sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_NAME);
    sheet.appendRow(HEADERS);
  }

  const action = body.action || "upsert";
  const sessions = body.sessions || [];
  const data = sheet.getDataRange().getValues();

  if (action === "replace" && sessions.length > 0) {
    const incomingIds = new Set(sessions.map(s => s.id));
    for (let r = data.length - 1; r >= 1; r--) {
      if (incomingIds.has(data[r][0])) sheet.deleteRow(r + 1);
    }
  }

  for (const s of sessions) {
    const row = [s.id, s.project, s.startTime, s.endTime || "", s.hours || 0,
                 s.summary || "", (s.notes || []).join("; "), (s.commits || []).join("; "),
                 s.deleted ? "yes" : ""];
    // upsert by id
    let updated = false;
    for (let r = 1; r < data.length; r++) {
      if (data[r][0] === s.id) {
        sheet.getRange(r + 1, 1, 1, row.length).setValues([row]);
        updated = true;
        break;
      }
    }
    if (!updated) sheet.appendRow(row);
  }

  return ContentService.createTextOutput(JSON.stringify({ok: true, count: sessions.length}))
                       .setMimeType(ContentService.MimeType.JSON);
}
```

### 2. Deploy as a web app

Click **Deploy → New deployment → Web app**. Set "Execute as: Me" and "Who has access: Anyone with the link". Copy the deployment URL.

### 3. Point PunchCard at it

```bash
punchcard config set-webhook "https://script.google.com/macros/s/AKfycb.../exec"
# optional shared secret (must match SHARED_SECRET in the Apps Script):
punchcard config set-secret "some-long-random-string"
```

From then on, every `punchcard stop` pushes that session to the sheet. Pass `--no-sync` to skip for a single invocation, or `punchcard config disable` to pause.

To backfill history or reconcile after edits:

```bash
punchcard sync                                   # upsert every completed session
punchcard sync --from 2026-04-01 --to 2026-04-30 # scoped range
punchcard sync --replace                         # remove and re-append rows in scope
```

The webhook URL is a capability — treat it like a secret. It is stored at `~/.punchcard/sync.json` (chmod 600).

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

91 tests across 14 suites covering models, stores, PDF generation (with text extraction), CSV export, edit/delete/undelete, file locking, backup, and integration workflows.

## Requirements

- macOS 13+
- Swift 6.0+
