# Invoice: Generate a PDF Invoice

Generate a PDF invoice for tracked work sessions over a date range.

## Instructions

1. **Parse the user's message** after `/invoice` for parameters. The user might provide them naturally:
   - `/invoice last two weeks at $150/hr for Acme Corp`
   - `/invoice March 2026 rate 125 client "Jane Smith"`
   - `/invoice --from 2026-03-01 --to 2026-03-31 --rate 150`

2. **Determine required parameters**:
   - `--from DATE` (yyyy-MM-dd)
   - `--to DATE` (yyyy-MM-dd)
   - `--rate RATE` (hourly rate as a positive number)
   - `--name NAME` (the user's name for the invoice)
   - `--client CLIENT` (client/employer name)
   - `--project PROJECT` (optional filter by project)
   - `--output PATH` (optional, defaults to ~/.punchcard/invoices/)
   - `--logo PATH` (optional, path to a logo image to display as a watermark)

   If any required parameter is missing, ask the user for it. Convert natural language dates to yyyy-MM-dd:
   - "last week" = Monday to Sunday of the previous week
   - "this month" = 1st of current month to today
   - "March" or "March 2026" = 2026-03-01 to 2026-03-31
   - "last two weeks" = 14 days ago to today

   **Important**: After converting dates, tell the user the exact dates you computed and confirm they are correct before proceeding.

3. **Preview the sessions** that will be included:
   ```
   punchcard list --from DATE --to DATE [--project PROJECT]
   ```
   Show the user the sessions and total hours. Ask for confirmation before generating.

4. **Generate the invoice**:
   ```
   punchcard invoice --from DATE --to DATE --rate RATE --name "NAME" --client "CLIENT" [--project PROJECT] [--output PATH] [--logo PATH]
   ```

5. **Report** the output file path, invoice number, and total amount.

## Arguments
$ARGUMENTS
