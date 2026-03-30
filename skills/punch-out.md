# Punch Out: End a Work Session

End the current work session, generate a summary of work done, capture git commits, and save everything.

## Instructions

1. **Check session status**:
   ```
   punchcard status
   ```
   If no active session exists, inform the user and stop. Note the start time and ISO8601 timestamp from the output — you need them for the git log.

2. **Gather git commits** made during the session. Using the ISO8601 start time from step 1:
   ```
   git log --oneline --after="START_TIME_ISO8601" --before="now"
   ```
   Collect the output. If the command fails (e.g., not a git repo), skip commits — that's fine.

3. **Write a session summary**: Review your conversation history from this chat session. Write a concise 1-3 sentence summary of what was accomplished. Focus on **outcomes**, not process:
   - Good: "Implemented JWT authentication and added login/signup endpoints with unit tests."
   - Bad: "We discussed various approaches and made some changes to the code."

   If the user included a message after `/punch-out` (e.g., `/punch-out also refactored the navbar`), incorporate that into your summary.

4. **Write summary and commits to temp files** to avoid shell escaping issues.
   Use the Write tool to write the summary to `/tmp/punchcard-summary.txt` and
   the commits (if any) to `/tmp/punchcard-commits.txt`. Do NOT use echo or
   shell commands to write these files — use the Write tool directly to avoid
   any shell escaping issues with quotes, backticks, or special characters.

5. **Stop the session** using the file-based flags:
   ```
   punchcard stop --summary-file /tmp/punchcard-summary.txt [--commits-file /tmp/punchcard-commits.txt]
   ```

6. **Clean up** the temp files:
   ```
   rm -f /tmp/punchcard-summary.txt /tmp/punchcard-commits.txt
   ```

7. **Report** to the user: show the session duration, your summary, and number of commits captured. Keep it concise.

## Important
- YOU (Claude) write the summary based on conversation context. Do not ask the user to write it.
- Be specific about what was done — mention files, features, or bugs by name.
- Always use --summary-file instead of --summary to avoid shell escaping issues with quotes and special characters.

## Arguments
$ARGUMENTS
