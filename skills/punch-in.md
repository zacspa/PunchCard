# Punch In: Start a Work Session

Begin tracking a new work session using the PunchCard CLI.

## Instructions

1. **Check for an active session first**:
   ```
   punchcard status
   ```
   If a session is already active, inform the user and ask if they want to stop it first.

2. **Parse arguments**: Check if the user provided a project name after `/punch-in` (e.g., `/punch-in MyProject`).

3. **If no project name was provided**, list available projects:
   ```
   punchcard project list
   ```
   Show the list to the user and ask them to pick one. If no projects are registered, tell them to add one with `punchcard project add "Name"`.

4. **Start the session**:
   ```
   punchcard start --project "ProjectName"
   ```

5. **Confirm** to the user that the session has started. Keep it to one or two lines showing the project name and start time.

## Arguments
$ARGUMENTS
