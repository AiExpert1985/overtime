import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../data/reports_repository.dart';
import '../domain/report.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(dbProvider));
});

class ReportsNotifier extends AsyncNotifier<List<Report>> {
  @override
  Future<List<Report>> build() =>
      ref.read(reportsRepositoryProvider).loadReports();

  Future<void> deleteReport(int id) async {
    await ref.read(reportsRepositoryProvider).deleteReport(id);
    ref.invalidateSelf();
  }
}

final reportsProvider =
    AsyncNotifierProvider<ReportsNotifier, List<Report>>(ReportsNotifier.new);
