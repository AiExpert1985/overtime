import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/column_headers_repository.dart';
import '../../../../shared/database/database_helper.dart';

// Incremented after every add/edit/delete so InputScreen can detect stale state.
class _HeadersVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}

final headersVersionProvider =
    NotifierProvider<_HeadersVersionNotifier, int>(_HeadersVersionNotifier.new);

class ColumnHeadersNotifier
    extends AsyncNotifier<Map<String, Map<String, List<ColumnHeaderItem>>>> {
  late final ColumnHeadersRepository _repo;

  @override
  Future<Map<String, Map<String, List<ColumnHeaderItem>>>> build() async {
    _repo = ColumnHeadersRepository(DatabaseHelper.instance);
    return _repo.getAllHeaders();
  }

  Future<String?> addHeader(String fileType, String fieldKey, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'القيمة لا يمكن أن تكون فارغة';
    final exists = await _repo.headerValueExists(fileType, fieldKey, trimmed);
    if (exists) return 'هذه القيمة موجودة بالفعل';

    await _repo.addHeader(fileType, fieldKey, trimmed);
    ref.read(headersVersionProvider.notifier).increment();
    state = AsyncData(await _repo.getAllHeaders());
    return null;
  }

  Future<String?> updateHeader(int id, String fileType, String fieldKey, String newValue) async {
    final trimmed = newValue.trim();
    if (trimmed.isEmpty) return 'القيمة لا يمكن أن تكون فارغة';
    final exists = await _repo.headerValueExists(fileType, fieldKey, trimmed);
    if (exists) return 'هذه القيمة موجودة بالفعل';

    await _repo.updateHeader(id, trimmed);
    ref.read(headersVersionProvider.notifier).increment();
    state = AsyncData(await _repo.getAllHeaders());
    return null;
  }

  Future<void> deleteHeader(int id) async {
    await _repo.deleteHeader(id);
    ref.read(headersVersionProvider.notifier).increment();
    state = AsyncData(await _repo.getAllHeaders());
  }
}

final columnHeadersProvider = AsyncNotifierProvider<ColumnHeadersNotifier,
    Map<String, Map<String, List<ColumnHeaderItem>>>>(ColumnHeadersNotifier.new);
