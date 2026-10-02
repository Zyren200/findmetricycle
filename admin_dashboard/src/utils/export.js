// Report exports without extra libraries:
//  - CSV: plain comma-separated text (UTF-8 with BOM so Excel reads ₱ etc.)
//  - Excel: an HTML-table workbook that Excel opens as a spreadsheet (.xls)
//  - PDF: a print-ready page; the browser's "Save as PDF" writes the file.
//
// Every export takes a list of sections: { title, columns: [{ key, label }], rows }.

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function csvCell(value) {
  const text = String(value ?? "");
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function download(filename, mime, content) {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function stamp() {
  return new Date().toISOString().slice(0, 10);
}

export function exportCsv(name, sections) {
  const lines = [];
  sections.forEach((section, i) => {
    if (i > 0) lines.push("");
    lines.push(csvCell(section.title));
    lines.push(section.columns.map((c) => csvCell(c.label)).join(","));
    section.rows.forEach((row) => lines.push(section.columns.map((c) => csvCell(row[c.key])).join(",")));
  });
  download(`${name}-${stamp()}.csv`, "text/csv;charset=utf-8", `﻿${lines.join("\r\n")}`);
}

function tablesHtml(sections) {
  return sections
    .map(
      (section) => `
        <h2>${escapeHtml(section.title)}</h2>
        <table>
          <thead><tr>${section.columns.map((c) => `<th>${escapeHtml(c.label)}</th>`).join("")}</tr></thead>
          <tbody>${
            section.rows.length
              ? section.rows
                  .map((row) => `<tr>${section.columns.map((c) => `<td>${escapeHtml(row[c.key])}</td>`).join("")}</tr>`)
                  .join("")
              : `<tr><td colspan="${section.columns.length}">No records.</td></tr>`
          }</tbody>
        </table>`
    )
    .join("");
}

export function exportExcel(name, sections) {
  const html = `<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel">
    <head><meta charset="utf-8" /></head>
    <body>${tablesHtml(sections)}</body></html>`;
  download(`${name}-${stamp()}.xls`, "application/vnd.ms-excel;charset=utf-8", `﻿${html}`);
}

export function exportPdf(title, sections) {
  const win = window.open("", "_blank", "width=1000,height=800");
  if (!win) {
    alert("Allow pop-ups for this site to export the PDF report.");
    return;
  }
  win.document.write(`<!doctype html><html><head><meta charset="utf-8" />
    <title>${escapeHtml(title)} — ${stamp()}</title>
    <style>
      body{font-family:Arial,Helvetica,sans-serif;color:#111827;margin:24px}
      h1{font-size:20px;margin:0 0 4px} .sub{color:#6b7280;font-size:12px;margin-bottom:16px}
      h2{font-size:14px;margin:20px 0 8px}
      table{width:100%;border-collapse:collapse;font-size:11px}
      th,td{border:1px solid #d1d5db;padding:5px 6px;text-align:left;vertical-align:top}
      th{background:#f3f4f6}
      @media print{ h2{break-after:avoid} tr{break-inside:avoid} }
    </style></head>
    <body>
      <h1>${escapeHtml(title)}</h1>
      <div class="sub">FindMeTricycle · Generated ${escapeHtml(new Date().toLocaleString())}</div>
      ${tablesHtml(sections)}
      <script>window.onload = function(){ window.focus(); window.print(); };<\/script>
    </body></html>`);
  win.document.close();
}
