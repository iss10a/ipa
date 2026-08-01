/// Xtream Codes connection details. Persisted in the iOS keychain.
class Credentials {
  const Credentials({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  final String serverUrl;
  final String username;
  final String password;

  /// Normalised base without a trailing slash, always with a scheme.
  String get baseUrl {
    var url = serverUrl.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  bool get isValid =>
      baseUrl.isNotEmpty && username.trim().isNotEmpty && password.isNotEmpty;

  /// Direct download URL for a VOD stream.
  String movieUrl(int streamId, String extension) =>
      '$baseUrl/movie/$username/$password/$streamId.$extension';

  /// Direct download URL for a series episode.
  String episodeUrl(String episodeId, String extension) =>
      '$baseUrl/series/$username/$password/$episodeId.$extension';

  Credentials copyWith({
    String? serverUrl,
    String? username,
    String? password,
  }) =>
      Credentials(
        serverUrl: serverUrl ?? this.serverUrl,
        username: username ?? this.username,
        password: password ?? this.password,
      );
}
