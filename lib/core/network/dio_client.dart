import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../constants/app_constants.dart';

/// Builds the shared Dio instance.
///
/// Many Xtream panels are served over plain HTTP with self-signed or expired
/// certificates. The app therefore tolerates bad certificates on the user's own
/// server rather than failing the connection outright.
class DioClient {
  static Dio create() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: const {
          'User-Agent': 'XtreamDownloader/1.0 (iOS)',
          'Accept': '*/*',
        },
      ),
    );

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()
          ..idleTimeout = const Duration(seconds: 30)
          ..maxConnectionsPerHost = 16;
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );

    return dio;
  }
}
