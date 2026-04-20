# Punch In: Start a Work Session

Begin tracking a new work session using the PunchCard CLI.

## Instructions

1. **Check for an active session first**:
   ```
   punchcard status
   ```
   If a session is already active, inform the user and ask if they want to stop it first.

2. **Parse arguments** from `$ARGUMENTS`. The user may include:
   - A **project name** — e.g. `/punch-in Acme Corp`
   - A **backdated time** using natural phrasing — e.g.
     - `/punch-in at 12:00pm`
     - `/punch-in Acme at 9:15am`
     - `/punch-in 30 minutes ago`
     - `/punch-in Acme 1h ago`
     - `/punch-in at 2026-04-18 09:00`

   Extract the project name and, if present, a time phrase. If the phrase begins with "at", pass the remainder to `--at`. If it ends with "ago", convert to `--ago` (e.g. "30 minutes ago" → `--ago 30m`, "1h ago" → `--ago 1h`, "an hour ago" → `--ago 1h`).

3. **If no project name was provided**, list available projects:
   ```
   punchcard project list
   ```
   Show the list to the user and ask them to pick one. If no projects are registered, tell them to add one with `punchcard project add "Name"`.

4. **Start the session** with the resolved arguments:
   ```
   punchcard start --project "ProjectName"
   # or
   punchcard start --project "ProjectName" --at "12:00pm"
   # or
   punchcard start --project "ProjectName" --ago "30m"
   ```

   `--at` accepts: `HH:mm`, `h:mma` / `h:mm a` (e.g. `12:00pm`, `9:15 am`), `ha`, `yyyy-MM-dd HH:mm`, full ISO 8601. `--ago` accepts `30m`, `1h`, `1h30m`, or a bare integer for minutes.

5. **Confirm** to the user that the session has started. Keep it to one or two lines showing the project name and start time.

## Arguments
$ARGUMENTS
