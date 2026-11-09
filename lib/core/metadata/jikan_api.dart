import 'dart:async';

import 'package:dio/dio.dart';

/// Shared, rate-limited access to Jikan so detail sections do not burst the
/// API with several simultaneous requests when one anime page opens.
class JikanApi {
  JikanApi._();

  static Future<void> _tail = Future<void>.value();
  static DateTime? _lastRequestAt;
  static const Duration _minimumGap = Duration(milliseconds: 380);

  static Future<dynamic> get(
    Dio dio,
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    await previous;

    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        final last = _lastRequestAt;
        if (last != null) {
          final elapsed = DateTime.now().difference(last);
          if (elapsed < _minimumGap) {
            await Future<void>.delayed(_minimumGap - elapsed);
          }
        }
        _lastRequestAt = DateTime.now();

        try {
          final response = await dio.get<dynamic>(
            url,
            queryParameters: query,
            options: Options(
              headers: headers,
              validateStatus: (status) => status != null && status < 600,
            ),
          );
          final status = response.statusCode ?? 200;
          if (status == 429 || status >= 500) {
            if (attempt == 2) {
              throw DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.badResponse,
              );
            }
            final retryAfter = int.tryParse(
              response.headers.value('retry-after') ?? '',
            );
            final waitMs = retryAfter != null
                ? (retryAfter * 1000).clamp(1200, 6000).toInt()
                : (status == 429 ? 1200 * (attempt + 1) : 700);
            await Future<void>.delayed(Duration(milliseconds: waitMs));
            continue;
          }
          return response.data;
        } on DioException catch (error) {
          final status = error.response?.statusCode;
          final retryable = status == null || status == 429 || status >= 500;
          if (!retryable || attempt == 2) rethrow;
          await Future<void>.delayed(
            Duration(milliseconds: status == 429 ? 1200 * (attempt + 1) : 700),
          );
        }
      }
      throw StateError('Jikan tidak merespons.');
    } finally {
      release.complete();
    }
  }
}
