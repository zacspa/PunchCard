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

# Start tracking
punchcard start --project "Acme Corp"

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
| `stop --summary TEXT` | Stop session with a summary |
| `stop --summary-file PATH` | Stop session with summary from a file (avoids shell escaping) |
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

## Data storage

All data is stored in `~/.punchcard/`:

| File | Purpose |
|---|---|
| `sessions.json` | All session data (including soft-deleted) |
| `sessions.json.bak` | Auto-backup of previous state |
| `projects.json` | Registered project names |
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
