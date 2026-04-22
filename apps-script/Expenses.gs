/**
 * PunchCard expense sync handler — paste into your sheet's Apps Script project
 * (Extensions → Apps Script) alongside your existing doPost handler.
 *
 * INTEGRATION:
 *
 * In your existing doPost(e), add a route for the new action:
 *
 *   function doPost(e) {
 *     var secret = e.parameter.secret;
 *     var data = JSON.parse(e.postData.contents);
 *
 *     if (data.action === 'upsert-expenses') {
 *       return PunchCardExpenses.handle(data);
 *     }
 *
 *     // ... existing session upsert logic ...
 *   }
 *
 * If you want the receipt images in a specific Drive folder, set
 * RECEIPTS_FOLDER_NAME. The folder is created on first use and reused after.
 */

/**
 * Run once from the Apps Script editor (Run button with this function selected
 * in the toolbar) to grant full Drive permissions. Touches both read
 * (getFoldersByName) and write (createFolder) so Google asks for the full
 * drive scope, not just drive.readonly. Creates then trashes a probe folder
 * so there's no lingering state. Redeploy the Web App after approving.
 */
function authorizePunchCardDrive() {
  DriveApp.getFoldersByName('__punchcard_auth_probe__');
  var probe = DriveApp.createFolder('__punchcard_auth_probe__');
  probe.setTrashed(true);
}

var PunchCardExpenses = (function () {
  var EXPENSES_SHEET_NAME = 'Expenses';
  var RECEIPTS_FOLDER_NAME = 'PunchCard Receipts';

  var COLUMNS = [
    'id',
    'project',
    'merchant',
    'amount_cents',
    'currency',
    'captured_at',
    'category',
    'billable',
    'note',
    'receipt_drive_id',
    'receipt_drive_url',
    'created_at',
    'updated_at',
    'deleted',
  ];

  function list(params) {
    var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(EXPENSES_SHEET_NAME);
    if (!sheet) return jsonOut_({ ok: true, expenses: [] });

    var lastRow = sheet.getLastRow();
    if (lastRow < 2) return jsonOut_({ ok: true, expenses: [] });

    var rows = sheet.getRange(2, 1, lastRow - 1, COLUMNS.length).getValues();
    var project = params.project || null;
    var from = params.from || null; // ISO date or ISO datetime; inclusive
    var to = params.to || null;     // ISO date or ISO datetime; inclusive
    var billableOnly = params.billable === '1' || params.billable === 'true';

    var out = [];
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i];
      var obj = {};
      for (var j = 0; j < COLUMNS.length; j++) obj[COLUMNS[j]] = r[j];

      if (obj.deleted) continue;
      if (project && obj.project !== project) continue;
      if (billableOnly && !obj.billable) continue;

      var captured = obj.captured_at;
      if (captured instanceof Date) {
        captured = captured.toISOString();
      } else {
        captured = captured ? String(captured) : '';
      }
      if (from && captured < from) continue;
      if (to && captured > to + 'T23:59:59.999Z') continue;

      out.push({
        id: String(obj.id),
        project: String(obj.project),
        merchant: String(obj.merchant || ''),
        amountCents: Number(obj.amount_cents) || 0,
        currency: String(obj.currency || 'USD'),
        capturedAt: captured,
        category: obj.category ? String(obj.category) : null,
        billable: !!obj.billable,
        note: obj.note ? String(obj.note) : null,
        receiptDriveId: obj.receipt_drive_id ? String(obj.receipt_drive_id) : null,
        receiptDriveUrl: obj.receipt_drive_url ? String(obj.receipt_drive_url) : null,
      });
    }

    return jsonOut_({ ok: true, expenses: out });
  }

  function handle(data) {
    if (!data || !Array.isArray(data.expenses)) {
      return jsonOut_({ ok: false, error: 'Missing expenses array' });
    }

    var sheet = ensureSheet_();
    var folder = ensureFolder_();

    var written = 0;
    for (var i = 0; i < data.expenses.length; i++) {
      var e = data.expenses[i];
      if (!e || !e.id) continue;

      var drive = null;
      if (e.receiptImageBase64) {
        try {
          drive = uploadReceipt_(folder, e.id, e.receiptImageBase64, e.receiptImageName || (e.id + '.jpg'));
        } catch (err) {
          // Keep going — we'd rather persist the row without the image than fail the whole batch.
          drive = null;
        }
      }

      upsertRow_(sheet, e, drive);
      written++;
    }

    return jsonOut_({ ok: true, written: written });
  }

  function ensureSheet_() {
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = ss.getSheetByName(EXPENSES_SHEET_NAME);
    if (!sheet) {
      sheet = ss.insertSheet(EXPENSES_SHEET_NAME);
      sheet.getRange(1, 1, 1, COLUMNS.length).setValues([COLUMNS]);
      sheet.setFrozenRows(1);
      sheet.getRange(1, 1, 1, COLUMNS.length).setFontWeight('bold');
    }
    return sheet;
  }

  function ensureFolder_() {
    var folders = DriveApp.getFoldersByName(RECEIPTS_FOLDER_NAME);
    if (folders.hasNext()) return folders.next();
    return DriveApp.createFolder(RECEIPTS_FOLDER_NAME);
  }

  function uploadReceipt_(folder, expenseId, base64, filename) {
    var decoded = Utilities.base64Decode(base64);
    var mime = guessMime_(filename);
    var blob = Utilities.newBlob(decoded, mime, filename);

    // Replace existing file for the same expense id, so retakes don't accumulate.
    var prefix = 'receipt-' + expenseId;
    var existing = folder.getFilesByName(prefix + extension_(filename));
    while (existing.hasNext()) existing.next().setTrashed(true);

    var file = folder.createFile(blob).setName(prefix + extension_(filename));
    return { id: file.getId(), url: file.getUrl() };
  }

  function extension_(name) {
    var dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(dot) : '';
  }

  function guessMime_(name) {
    var ext = extension_(name).toLowerCase();
    if (ext === '.png') return MimeType.PNG;
    if (ext === '.heic' || ext === '.heif') return 'image/heic';
    return MimeType.JPEG;
  }

  function upsertRow_(sheet, e, drive) {
    var row = [
      e.id,
      e.project,
      e.merchant || '',
      e.amountCents != null ? e.amountCents : 0,
      e.currency || 'USD',
      e.capturedAt || '',
      e.category || '',
      e.billable ? 1 : 0,
      e.note || '',
      drive ? drive.id : '',
      drive ? drive.url : '',
      e.createdAt || '',
      e.updatedAt || '',
      e.deleted ? 1 : 0,
    ];

    var lastRow = sheet.getLastRow();
    if (lastRow < 2) {
      sheet.getRange(2, 1, 1, row.length).setValues([row]);
      return;
    }

    // Find existing row by id (column A). Fast enough for thousands of rows.
    var idColumn = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
    for (var i = 0; i < idColumn.length; i++) {
      if (idColumn[i][0] === e.id) {
        var existingRow = i + 2;
        // Preserve the existing Drive columns if this upsert didn't include an image.
        if (!drive) {
          var existing = sheet.getRange(existingRow, 10, 1, 2).getValues()[0];
          row[9] = existing[0];
          row[10] = existing[1];
        }
        sheet.getRange(existingRow, 1, 1, row.length).setValues([row]);
        return;
      }
    }
    sheet.getRange(lastRow + 1, 1, 1, row.length).setValues([row]);
  }

  function jsonOut_(obj) {
    return ContentService
      .createTextOutput(JSON.stringify(obj))
      .setMimeType(ContentService.MimeType.JSON);
  }

  return { handle: handle, list: list };
})();
