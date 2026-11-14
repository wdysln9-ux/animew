import 'dart:async';

import 'package:dio/dio.dart';

/// Shared, rate-limited access to Jikan so detail sections can load in
/// parallel without exceeding the API's request budget.
class JikanApi {
  JikanApi._();

  /// Serializes only slot reservation, never the HTTP request itself.
  /// The old queue held this lock until each response completed, accidentally
  /// turning independent endpoints into a slow request-by-request chain.
  static Future<void> _reservationTail = Future<void>.value();
  static DateTime? _lastRequestAt;
  static final List<DateTime> _recentStarts = <DateTime>[];
  static const Duration _minimumGap = Duration(milliseconds: 380);
  static const Duration _window = Duration(minutes: 1);
  static const int _requestsPerWindow = 55;

  static Future<void> _reserveRequestSlot() async {
    final previous = _reservationTail;
    final release = Completer<void>();
    _reservationTail = release.future;
    await previous;

    try {
      while (true) {
        var now = DateTime.now();
        _recentStarts.removeWhere(
          (started) => now.difference(started) >= _window,
        );

        var wait = Duration.zero;
        if (_recentStarts.length >= _requestsPerWindow) {
          final untilWindowOpens = _recentStarts.first.add(_window).difference(now);
          if (untilWindowOpens > wait) wait = untilWindowOpens;
        }

        final last = _lastRequestAt;
        if (last != null) {
          final untilNextSlot = _minimumGap - now.difference(last);
          if (untilNextSlot > wait) wait = untilNextSlot;
        }

        if (wait > Duration.zero) {
          await Future<void>.delayed(wait);
          continue;
        }

        now = DateTime.now();
        _lastRequestAt = now;
        _recentStarts.add(now);
        return;
      }
    } finally {
      // Release as soon as this request has a reserved start time. Its network
      // response is intentionally allowed to overlap the next request.
      release.complete();
    }
  }

  static Future<dynamic> get(
    Dio dio,
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      await _reserveRequestSlot();

      try {
        final response = await dio.get<dynamic>(
          url,
          queryParameters: query,
          options: Options(
            headers: headers,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 10),
            validateStatus: (status) => status != null && status < 400,
          ),
        );
        return response.data;
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        final retryable = status == null || status == 429 || status >= 500;
        if (!retryable || attempt == 2) rethrow;

        final retryAfter = int.tryParse(
          error.response?.headers.value('retry-after') ?? '',
        );
        final waitMs = retryAfter != null
            ? (retryAfter * 1000).clamp(1200, 6000).toInt()
            : (status == 429 ? 1200 * (attempt + 1) : 700);
        await Future<void>.delayed(Duration(milliseconds: waitMs));
      }
    }
    throw StateError('Jikan tidak merespons.');
  }
}
