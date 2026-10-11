// MariaDB (XAMPP) returns JSON columns as strings; MySQL 8 (Railway)
// returns them already parsed. Accepts either; bad JSON becomes null.
function parseJsonColumn(value) {
  if (value == null || value === "") return null;
  if (typeof value !== "string") return value;
  try {
    return JSON.parse(value);
  } catch (_error) {
    return null;
  }
}

module.exports = parseJsonColumn;
