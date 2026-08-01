import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import '../core/error/exceptions.dart';
import '../core/utils/filename_sanitizer.dart';

/// Owns every path decision. Files land in the app's Documents directory, which
/// is visible in the iOS Files app (see UIFileSharingEnabled in Info.plist) and
/// is never purged by the system the way Caches is.
class StoragePaths {
  StoragePaths._(this.documentsRoot);

  final String documentsRoot;

  static StoragePaths? _instance;

  static Future<StoragePaths> instance() async {
    if (_instance != null) return _instance!;
    // Application Support, not Documents: Documents is exposed to the Files app
    // whenever file sharing is enabled, and is also what iTunes/Finder back up
    // and surface. Application Support is private to the app and still survives
    // between launches, unlike Caches which the system may purge.
    final dir = await getApplicationSupportDirectory();
    final root = p.join(dir.path, AppConstants.downloadsRoot);
    await Directory(root).create(recursive: true);
    await Directory(p.join(root, AppConstants.moviesFolder))
        .create(recursive: true);
    await Directory(p.join(root, AppConstants.seriesFolder))
        .create(recursive: true);
    _instance = StoragePaths._(root);
    return _instance!;
  }

  /// Downloads/Movies/<Movie Name>/<Movie Name>.mp4
  ///
  /// Each film lives in its own folder so the library browser can treat a
  /// title as a single unit, and so deleting it removes everything at once.
  static String movieRelativePath(String rawName, String extension) {
    final folder = FilenameSanitizer.sanitizeSegment(rawName);
    final file = FilenameSanitizer.withExtension(rawName, extension);
    return p.join(AppConstants.moviesFolder, folder, file);
  }

  /// Folder that holds a single film.
  static String movieFolder(String rawName) =>
      p.join(AppConstants.moviesFolder, FilenameSanitizer.sanitizeSegment(rawName));

  /// Folder that holds every season of one series.
  static String seriesFolder(String rawSeriesName) =>
      p.join(AppConstants.seriesFolder,
          FilenameSanitizer.sanitizeSegment(rawSeriesName));

  /// Folder that holds one season of one series.
  static String seasonFolder(String rawSeriesName, int seasonNumber) => p.join(
        AppConstants.seriesFolder,
        FilenameSanitizer.sanitizeSegment(rawSeriesName),
        'Season ${seasonNumber.toString().padLeft(2, '0')}',
      );

  /// Downloads/Series/<Series Name>/Season 01/<Episode Name>.mp4
  static String episodeRelativePath({
    required String rawSeriesName,
    required int seasonNumber,
    required String rawEpisodeTitle,
    required String extension,
  }) {
    final series = FilenameSanitizer.sanitizeSegment(rawSeriesName);
    final season = 'Season ${seasonNumber.toString().padLeft(2, '0')}';
    final file = FilenameSanitizer.withExtension(rawEpisodeTitle, extension);
    return p.join(AppConstants.seriesFolder, series, season, file);
  }

  String absolute(String relativePath) => p.join(documentsRoot, relativePath);

  /// Directory portion of [relativePath], created if missing.
  Future<Directory> ensureParent(String relativePath) async {
    final dir = Directory(p.dirname(absolute(relativePath)));
    if (!await dir.exists()) {
      try {
        await dir.create(recursive: true);
      } on FileSystemException catch (e) {
        throw StorageException('تعذّر إنشاء المجلد: ${e.message}');
      }
    }
    return dir;
  }

  /// Partial file used while bytes are in flight.
  String partialPath(String relativePath) => '${absolute(relativePath)}.part';

  Future<bool> exists(String relativePath) =>
      File(absolute(relativePath)).exists();

  Future<int> sizeOf(String relativePath) async {
    final file = File(absolute(relativePath));
    if (!await file.exists()) return 0;
    return file.length();
  }

  /// Removes both the finished file and any leftover partial data.
  Future<void> deleteFile(String relativePath) async {
    for (final path in [absolute(relativePath), partialPath(relativePath)]) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } on FileSystemException {
          // Best effort: a locked file should not crash the queue.
        }
      }
    }
    await _pruneEmptyParents(p.dirname(absolute(relativePath)));
  }

  /// Atomically moves the partial file into its final name.
  Future<void> finalize(String relativePath) async {
    final partial = File(partialPath(relativePath));
    if (!await partial.exists()) return;
    final target = File(absolute(relativePath));
    if (await target.exists()) await target.delete();
    await partial.rename(target.path);
  }

  /// Walks up removing directories left empty after a delete, stopping at root.
  Future<void> _pruneEmptyParents(String dirPath) async {
    var current = Directory(dirPath);
    while (p.isWithin(documentsRoot, current.path)) {
      if (!await current.exists()) {
        current = current.parent;
        continue;
      }
      final isEmpty = await current.list().isEmpty;
      if (!isEmpty) return;
      try {
        await current.delete();
      } on FileSystemException {
        return;
      }
      current = current.parent;
    }
  }

  /// Removes a whole folder and everything inside it. Used when the user
  /// deletes an entire film or series from the library.
  Future<void> deleteDirectory(String relativeDir) async {
    final dir = Directory(absolute(relativeDir));
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // A locked file must not abort the rest of the deletion.
      }
    }
    await _pruneEmptyParents(p.dirname(absolute(relativeDir)));
  }

  /// Total bytes currently occupied by downloads.
  Future<int> usedBytes() async {
    final root = Directory(documentsRoot);
    if (!await root.exists()) return 0;
    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // File vanished mid-scan.
        }
      }
    }
    return total;
  }
}
