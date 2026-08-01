import '../entities/download_task.dart';

abstract interface class DownloadRepository {
  Future<List<DownloadItem>> loadAll();
  Future<void> upsert(DownloadItem item);
  Future<void> upsertAll(List<DownloadItem> items);
  Future<void> remove(String id);
  Future<void> removeAll(Iterable<String> ids);
  Future<void> clear();
}
