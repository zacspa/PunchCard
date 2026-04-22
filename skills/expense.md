# Expense: Add an Expense from a Receipt

Add a new expense to the PunchCard sheet by extracting fields from a dropped receipt image.

## Instructions

1. **Expect a receipt image.** The user may attach the image directly (Claude Code vision) or include a local path in `$ARGUMENTS`. If neither is present, ask for one.

2. **Read the receipt with vision and extract:**
   - `merchant` — vendor name at the top of the receipt (strip address/city/zip)
   - `amount` — the **grand total**, including tax and tip. Not a subtotal, not a line item, not the tip alone. If ambiguous, say so and ask.
   - `date` — transaction date (yyyy-MM-dd)
   - `time` — transaction time in HH:mm (24-hour), if printed
   - `category` — best guess from: `meals`, `travel`, `software`, `supplies`, or a custom one-word label

   If the receipt is faded, cropped, or unreadable, extract what you can and ask the user to fill in the rest. Never invent fields.

3. **Parse additional args** from `$ARGUMENTS`. The user may specify:
   - A project — `--project "Acme"`, or just a bare name
   - A note — `--note "..."`
   - `--not-billable` to mark as personal

4. **Identify the project.** Priority:
   1. Explicitly passed in args
   2. Currently active session — check with `punchcard status`; if active, offer that project as default ("This session is tracked to Acme — add to that?").
   3. Otherwise list projects (`punchcard project list`) and ask.

5. **Show extracted + resolved values** and ask for confirmation:
   ```
   Merchant: Café Grumpy
   Amount:   $14.20
   Date:     2026-04-21 12:30
   Category: meals
   Project:  Acme
   Billable: yes
   Image:    /tmp/receipt-xxxxx.jpg
   ```
   Only proceed on explicit confirmation ("yes", "go", "looks good"). If any field is uncertain, call it out specifically before asking to confirm.

6. **Add the expense:**
   ```
   punchcard expense add \
     --project "Acme" \
     --merchant "Café Grumpy" \
     --amount 14.20 \
     --date 2026-04-21 \
     --time 12:30 \
     --category meals \
     --image /path/to/receipt.jpg
   ```
   Pass `--image` when there's a local file path available. If the user only attached the image via vision (no path), save it to a temp file first and pass that path — the CLI base64-encodes the file and uploads to Drive via the same pipeline the mobile app uses.

   Append `--not-billable` or `--note "..."` when applicable.

7. **Report** the CLI's output — merchant, amount, project, and whether the receipt was attached.

## Notes

- The CLI posts directly to the configured webhook (`punchcard config show` to check). If `notConfigured` errors surface, guide the user to `punchcard config set-webhook <URL>` and `punchcard config set-secret`.
- Apps Script must have the `PunchCardExpenses.handle` route wired up (see `apps-script/README.md`). If writes fail with a 4xx/5xx, have the user check the Apps Script Executions log.
- Keep the conversation tight — the user wants a receipt logged, not a walkthrough.

## Arguments
$ARGUMENTS
