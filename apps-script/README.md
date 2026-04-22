# Apps Script — PunchCard sync handlers

The PunchCard mobile app and CLI both sync to a Google Sheet via a webhook
implemented as a Google Apps Script Web App bound to the sheet. The sheet is
the source of truth for reporting; the mobile DB and CLI store are local
caches that push into it.

This folder holds canonical reference copies of the Apps Script handlers. The
code actually runs inside the sheet's Apps Script project (Extensions → Apps
Script), not from this repo — there's no deploy automation. When you change
a handler, paste the new version into the script editor and redeploy the Web
App.

## Files

- `Expenses.gs` — handler for `action: "upsert-expenses"` from the mobile app.
  Creates the `Expenses` sheet tab on first use, uploads receipt images to
  a `PunchCard Receipts` Drive folder, writes one row per expense. Paste this
  into your script project and route to it from your existing `doPost`.

## Integration

Your existing `doPost(e)` likely handles `action: "upsert"` for sessions.
Route the new action to the expense handler:

```js
function doPost(e) {
  var secret = e.parameter.secret;
  // ... your existing secret check ...

  var data = JSON.parse(e.postData.contents);

  if (data.action === 'upsert-expenses') {
    return PunchCardExpenses.handle(data);
  }

  // ... your existing session upsert logic ...
}
```

After pasting and saving, redeploy the Web App (Deploy → Manage deployments →
edit → New version) so the new endpoint is live.

### Read endpoint (for Swift CLI invoice integration)

If you want `punchcard invoice --with-expenses` to pull billable expenses from
the sheet for inclusion on invoices, also add a `doGet` route. Same shared
secret as your writes — no new auth:

```js
function doGet(e) {
  var secret = e.parameter.secret;
  // ... your existing secret check (same guard as doPost) ...

  if (e.parameter.resource === 'expenses') {
    return PunchCardExpenses.list(e.parameter);
  }

  return ContentService
    .createTextOutput(JSON.stringify({ ok: false, error: 'Unknown resource' }))
    .setMimeType(ContentService.MimeType.JSON);
}
```

The CLI will call `GET <webhookURL>?secret=…&resource=expenses&project=Foo&from=2026-04-01&to=2026-04-30&billable=1`
and receive `{ ok: true, expenses: [...] }`.
