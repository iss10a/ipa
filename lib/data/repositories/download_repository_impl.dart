import '../../domain/entities/download_task.dart';
import '../../domain/repositories/download_repository.dart';
import '../datasources/local_store.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  DownloadRepositoryImpl(this._local);

  final LocalStore _local;

  @override
  Future<List<DownloadItem>> loadAll() async {
    final rows = _local.readDownloads();
    final items = <DownloadItem>[];
    for (final row in rows) {
      try {
        items.add(DownloadItem.fromJson(row));
      } catch (_) {
        // Ignore unreadable rows rather than blocking app start.
      }
    }
    items.sort((a, b) {
      final byPriority = a.priority.weight.compareTo(b.priority.weight);
      if (byPriority != 0) return byPriority;
      final bySequence = a.sequenceIndex.compareTo(b.sequenceIndex);
      if (bySequence != 0) return bySequence;
      return a.createdAt.compareTo(b.createdAt);
    });
    return items;
  }

  @override
  Future<void> upsert(DownloadItem item) =>
      _local.writeDownload(item.id, item.toJson());

  @override
  Future<void> upsertAll(List<DownloadItem> items) => _local.writeDownloads({
        for (final item in items) item.id: item.toJson(),
      });

  @override
  Future<void> remove(String id) => _local.deleteDownload(id);

  @override
  Future<void> removeAll(Iterable<String> ids) => _local.deleteDownloads(ids);

  @override
  Future<void> clear() => _local.clearDownloads();
}
