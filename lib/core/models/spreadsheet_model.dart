class Spreadsheet {
  String id;
  String name;
  List<String> columns;
  List<Map<String, String>> rows;

  Spreadsheet({
    required this.id,
    required this.name,
    required this.columns,
    required this.rows,
  });

  factory Spreadsheet.empty({required String id, required String name}) {
    List<String> cols = [];
    for (int i = 0; i < 26; i++) {
      cols.add(String.fromCharCode(65 + i));
    }
    List<Map<String, String>> initialRows = [];
    for (int i = 0; i < 50; i++) {
      Map<String, String> row = {};
      for (String col in cols) {
        row[col] = '';
      }
      initialRows.add(row);
    }
    return Spreadsheet(id: id, name: name, columns: cols, rows: initialRows);
  }
}

// Global mock data for sheets
class MockSpreadsheets {
  static List<Spreadsheet> sheets = [
    Spreadsheet.empty(id: '1', name: 'Monday Leads'),
  ];
}
