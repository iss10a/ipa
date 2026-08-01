/// Converts a server-supplied title into a filesystem-safe path segment.
///
/// The original, untouched title is always what gets stored in the database and
/// shown in the UI. This helper is used *only* when building the on-disk path,
/// and it changes the minimum number of characters required by APFS / iOS.
class FilenameSanitizer {
  FilenameSanitizer._();

  /// Characters that are either illegal in a path segment or break tooling.
  static final RegExp _illegal = RegExp(r'[/\\:\*\?"<>\|\x00-\x1F]');

  /// Trailing dots and spaces are stripped by some filesystems, which would
  /// silently change the name, so they are normalised away up front.
  static final RegExp _trailingJunk = RegExp(r'[. ]+$');

  static const int _maxSegmentBytes = 200;

  /// Returns a safe single path segment (no directory separators).
  static String sanitizeSegment(String raw) {
    var out = raw.replaceAll(_illegal, '_');
    out = out.replaceAll(_trailingJunk, '');
    out = out.trim();
    if (out.isEmpty) out = 'untitled';

    // Guard against overly long names while keeping the readable prefix.
    if (out.length > _maxSegmentBytes) {
      out = out.substring(0, _maxSegmentBytes).trim();
    }
    return out;
  }

  /// Builds "<sanitized name>.<ext>" ensuring exactly one dot.
  static String withExtension(String rawName, String rawExtension) {
    final base = sanitizeSegment(rawName);
    var ext = rawExtension.trim().replaceAll('.', '').toLowerCase();
    if (ext.isEmpty) ext = 'mp4';
    // If the server already put the extension in the title, do not double it.
    if (base.toLowerCase().endsWith('.$ext')) return base;
    return '$base.$ext';
  }
}
