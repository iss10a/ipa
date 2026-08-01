import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/exceptions.dart';
import '../../domain/entities/credentials.dart';

/// Thin, strictly-scoped client for the Xtream Codes `player_api.php` endpoint.
///
/// Only VOD and series actions are implemented. There is deliberately no method
/// for live streams, EPG, catchup or radio anywhere in this class.
class XtreamApi {
  XtreamApi(this._dio);

  final Dio _dio;

  static const Set<String> _allowedActions = {
    'get_vod_categories',
    'get_vod_streams',
    'get_vod_info',
    'get_series_categories',
    'get_series',
    'get_series_info',
  };

  /// Verifies credentials. Returns the `user_info` map when auth succeeds.
  Future<Map<String, dynamic>> authenticate(Credentials creds) async {
    final data = await _request(creds, null, const {});
    if (data is! Map) {
      throw const ServerException('استجابة غير متوقعة من الخادم.');
    }
    final userInfo = data['user_info'];
    if (userInfo is! Map) {
      throw const AuthException('بيانات الدخول غير صحيحة.');
    }
    final auth = userInfo['auth'];
    final status = (userInfo['status'] ?? '').toString().toLowerCase();
    if (auth != 1 && auth != '1') {
      throw const AuthException('اسم المستخدم أو كلمة المرور غير صحيحة.');
    }
    if (status == 'expired' || status == 'banned' || status == 'disabled') {
      throw AuthException('الحساب $status. راجع مزوّد الخدمة.');
    }
    return Map<String, dynamic>.from(userInfo);
  }

  Future<List<dynamic>> vodCategories(Credentials creds) async =>
      _asList(await _request(creds, 'get_vod_categories', const {}));

  Future<List<dynamic>> vodStreams(Credentials creds,
          {String? categoryId}) async =>
      _asList(await _request(creds, 'get_vod_streams', {
        if (categoryId != null) 'category_id': categoryId,
      }));

  Future<Map<String, dynamic>> vodInfo(Credentials creds, int vodId) async {
    final data = await _request(creds, 'get_vod_info', {'vod_id': '$vodId'});
    if (data is! Map) {
      throw const ServerException('تعذّر قراءة تفاصيل الفيلم.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<List<dynamic>> seriesCategories(Credentials creds) async =>
      _asList(await _request(creds, 'get_series_categories', const {}));

  Future<List<dynamic>> seriesList(Credentials creds,
          {String? categoryId}) async =>
      _asList(await _request(creds, 'get_series', {
        if (categoryId != null) 'category_id': categoryId,
      }));

  Future<Map<String, dynamic>> seriesInfo(
      Credentials creds, int seriesId) async {
    final data =
        await _request(creds, 'get_series_info', {'series_id': '$seriesId'});
    if (data is! Map) {
      throw const ServerException('تعذّر قراءة تفاصيل المسلسل.');
    }
    return Map<String, dynamic>.from(data);
  }

  /// Issues a HEAD request to learn the file size and whether the server
  /// honours HTTP Range, which decides if segmented downloading is possible.
  Future<({int? contentLength, bool acceptsRanges})> probe(String url) async {
    try {
      final response = await _dio.head<void>(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final headers = response.headers;
      final lengthRaw = headers.value(Headers.contentLengthHeader);
      final acceptRanges =
          headers.value('accept-ranges')?.toLowerCase().trim();
      return (
        contentLength: lengthRaw == null ? null : int.tryParse(lengthRaw),
        acceptsRanges: acceptRanges == 'bytes',
      );
    } on DioException {
      // A server that rejects HEAD is common; fall back to a plain download.
      return (contentLength: null, acceptsRanges: false);
    }
  }

  Future<dynamic> _request(
    Credentials creds,
    String? action,
    Map<String, String> extra,
  ) async {
    if (action != null && !_allowedActions.contains(action)) {
      // Hard guard: keeps live/EPG endpoints unreachable even by mistake.
      throw StateError('Action "$action" is not permitted in this app.');
    }

    final uri = '${creds.baseUrl}/player_api.php';
    try {
      final response = await _dio.get<dynamic>(
        uri,
        queryParameters: {
          'username': creds.username,
          'password': creds.password,
          if (action != null) 'action': action,
          ...extra,
        },
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: AppConstants.connectTimeout,
          receiveTimeout: AppConstants.receiveTimeout,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const AuthException('تم رفض الاتصال. تحقق من بيانات الدخول.');
      }
      if (response.statusCode != 200) {
        throw ServerException(
          'الخادم أرجع رمز ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }

      final body = (response.data ?? '').toString().trim();
      if (body.isEmpty) return const <dynamic>[];

      try {
        return jsonDecode(body);
      } on FormatException {
        // Some panels return an HTML error page with a 200 status.
        throw const ServerException(
            'الخادم أرجع رداً غير صالح. تأكد من رابط الخادم.');
      }
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    // Empty categories are sometimes returned as an object or `false`.
    return const <dynamic>[];
  }

  Exception _mapDioError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const NetworkException('انتهت مهلة الاتصال بالخادم.'),
      DioExceptionType.badCertificate =>
        const NetworkException('شهادة الخادم غير موثوقة.'),
      DioExceptionType.connectionError =>
        const NetworkException('تعذّر الوصول إلى الخادم. تحقق من الإنترنت.'),
      DioExceptionType.badResponse => ServerException(
          'الخادم أرجع رمز ${e.response?.statusCode}.',
          statusCode: e.response?.statusCode,
        ),
      _ => const NetworkException('فشل الاتصال بالخادم.'),
    };
  }
}
