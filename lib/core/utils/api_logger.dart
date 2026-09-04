import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Debug console logs for Supabase / HTTP traffic.
class ApiLogger {
  static const _tag = '[WorkPulse API]';

  static void info(String message) {
    if (kDebugMode) debugPrint('$_tag $message');
  }

  static void request({
    required String method,
    required Uri url,
    Map<String, String>? headers,
    Object? body,
  }) {
    if (!kDebugMode) return;
    debugPrint('$_tag ▶ REQUEST $method $url');
    if (headers != null && headers.isNotEmpty) {
      debugPrint('$_tag   headers: ${_redactHeaders(headers)}');
    }
    if (body != null) {
      debugPrint('$_tag   body: ${_redactBody(body)}');
    }
  }

  static void response({
    required String method,
    required Uri url,
    required int statusCode,
    String? body,
  }) {
    if (!kDebugMode) return;
    debugPrint('$_tag ◀ RESPONSE $statusCode $method $url');
    if (body != null && body.isNotEmpty) {
      final clipped = body.length > 4000 ? '${body.substring(0, 4000)}…' : body;
      debugPrint('$_tag   body: ${_redactBody(clipped)}');
    }
  }

  static void error(String where, Object error, [StackTrace? stack]) {
    if (!kDebugMode) return;
    debugPrint('$_tag ✖ ERROR $where: $error');
    if (stack != null) debugPrint('$stack');
  }

  static Map<String, String> _redactHeaders(Map<String, String> headers) {
    final out = <String, String>{};
    headers.forEach((key, value) {
      final k = key.toLowerCase();
      if (k == 'authorization' ||
          k == 'apikey' ||
          k == 'x-api-key' ||
          k.contains('password')) {
        out[key] = '***';
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  static Object _redactBody(Object body) {
    try {
      final decoded = body is String ? jsonDecode(body) : body;
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        for (final key in map.keys.toList()) {
          final lower = key.toLowerCase();
          if (lower.contains('password')) {
            final value = map[key];
            final len = value is String ? value.length : 0;
            map[key] = '<sent, $len chars>';
          } else if (lower.contains('token') ||
              lower == 'refresh_token' ||
              lower == 'access_token') {
            map[key] = '***';
          }
        }
        return map;
      }
    } catch (_) {}
    return body;
  }
}

/// Logs every HTTP request/response used by Supabase.
class LoggingHttpClient extends http.BaseClient {
  LoggingHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    String? requestBody;
    if (request is http.Request) {
      requestBody = request.body;
    }

    ApiLogger.request(
      method: request.method,
      url: request.url,
      headers: request.headers,
      body: requestBody,
    );

    final streamed = await _inner.send(request);
    final bytes = await streamed.stream.toBytes();
    final body = utf8.decode(bytes, allowMalformed: true);

    ApiLogger.response(
      method: request.method,
      url: request.url,
      statusCode: streamed.statusCode,
      body: body,
    );

    return http.StreamedResponse(
      Stream.value(bytes),
      streamed.statusCode,
      contentLength: bytes.length,
      request: streamed.request,
      headers: streamed.headers,
      reasonPhrase: streamed.reasonPhrase,
      isRedirect: streamed.isRedirect,
      persistentConnection: streamed.persistentConnection,
    );
  }

  @override
  void close() => _inner.close();
}
