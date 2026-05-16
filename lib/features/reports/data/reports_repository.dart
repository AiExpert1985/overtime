import 'package:sqflite/sqflite.dart';

import '../domain/report.dart';

class ReportsRepository {
  const ReportsRepository(this._db);

  final Database _db;

  Future<List<Report>> loadReports() async {
    final rows = await _db.query(
      'reports',
      columns: ['id', 'generation_datetime', 'range_start', 'range_end'],
      orderBy: 'generation_datetime DESC',
    );
    return rows.map(Report.fromMap).toList();
  }

  Future<void> deleteReport(int id) async {
    await _db.delete('reports', where: 'id = ?', whereArgs: [id]);
  }
}
