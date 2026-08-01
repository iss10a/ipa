import 'package:flutter_test/flutter_test.dart';
import 'package:pvo/domain/entities/credentials.dart';

void main() {
  group('Credentials', () {
    test('adds a scheme when the user omits it', () {
      const creds = Credentials(
          serverUrl: 'example.com:8080', username: 'u', password: 'p');
      expect(creds.baseUrl, 'http://example.com:8080');
    });

    test('strips trailing slashes', () {
      const creds = Credentials(
          serverUrl: 'http://example.com:8080///',
          username: 'u',
          password: 'p');
      expect(creds.baseUrl, 'http://example.com:8080');
    });

    test('builds the VOD download url', () {
      const creds = Credentials(
          serverUrl: 'http://host:80', username: 'user', password: 'pass');
      expect(creds.movieUrl(123, 'mkv'),
          'http://host:80/movie/user/pass/123.mkv');
    });

    test('builds the episode download url', () {
      const creds = Credentials(
          serverUrl: 'http://host:80', username: 'user', password: 'pass');
      expect(creds.episodeUrl('456', 'mp4'),
          'http://host:80/series/user/pass/456.mp4');
    });
  });
}
