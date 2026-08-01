import 'package:flutter_test/flutter_test.dart';
import 'package:pvo/core/utils/filename_sanitizer.dart';

void main() {
  group('FilenameSanitizer', () {
    test('leaves a clean server title untouched', () {
      expect(
        FilenameSanitizer.withExtension('Breaking Bad S01E01 Pilot', 'mp4'),
        'Breaking Bad S01E01 Pilot.mp4',
      );
    });

    test('keeps Arabic titles intact', () {
      expect(
        FilenameSanitizer.withExtension('الرسالة - الجزء الأول', 'mkv'),
        'الرسالة - الجزء الأول.mkv',
      );
    });

    test('replaces only characters iOS rejects', () {
      expect(
        FilenameSanitizer.sanitizeSegment('Law & Order: SVU 4/5'),
        'Law & Order_ SVU 4_5',
      );
    });

    test('does not duplicate an extension already in the title', () {
      expect(
        FilenameSanitizer.withExtension('Movie.mp4', 'mp4'),
        'Movie.mp4',
      );
    });

    test('falls back to mp4 when the server sends no container', () {
      expect(FilenameSanitizer.withExtension('Some Movie', ''),
          'Some Movie.mp4');
    });

    test('strips trailing dots that filesystems would drop silently', () {
      expect(FilenameSanitizer.sanitizeSegment('Title...'), 'Title');
    });
  });
}
