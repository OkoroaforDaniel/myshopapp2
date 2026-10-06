import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'models.dart';

/// Thin wrapper over the existing FastAPI backend.
/// Every path here is an endpoint the website already uses — no backend fork.
class Api {
  Api._();

  static Uri _uri(String path) => Uri.parse('${AppConfig.apiUrl}$path');

  static String? _token() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> _headers({bool auth = false}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final t = _token();
      if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final headers = _headers(auth: auth);
    late http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await http.get(_uri(path), headers: headers).timeout(const Duration(seconds: 45));
          break;
        case 'POST':
          res = await http
              .post(_uri(path), headers: headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 60));
          break;
        case 'PUT':
          res = await http
              .put(_uri(path), headers: headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 45));
          break;
        default:
          throw Exception('Unsupported method $method');
      }
    } catch (e) {
      throw ApiException('Network error — check your internet. ($e)');
    }
    Map<String, dynamic> json = <String, dynamic>{};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) json = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    if (res.statusCode >= 400) {
      final detail = json['detail'];
      throw ApiException(
        detail is String ? detail : 'Request failed (${res.statusCode})',
        status: res.statusCode,
      );
    }
    return json;
  }

  static Future<Map<String, dynamic>> get(String path, {bool auth = false}) =>
      _send('GET', path, auth: auth);

  static Future<Map<String, dynamic>> post(String path,
          {Map<String, dynamic>? body, bool auth = false}) =>
      _send('POST', path, body: body, auth: auth);

  static Future<Map<String, dynamic>> put(String path,
          {Map<String, dynamic>? body, bool auth = false}) =>
      _send('PUT', path, body: body, auth: auth);

  // ---------- Menu ----------
  static Future<List<Product>> products({String? category}) async {
    final q = (category == null || category == 'All' || category.isEmpty)
        ? ''
        : '?category=${Uri.encodeComponent(category)}';
    final j = await get('/api/products$q');
    final list = (j['products'] as List?) ?? const [];
    return list.map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  static Future<List<String>> categories() async {
    final j = await get('/api/categories');
    final list = (j['categories'] as List?) ?? const [];
    return list.map((e) => '$e').toList();
  }

  // ---------- Shared cart (web <-> mobile) ----------
  static Future<Map<String, dynamic>> getCart() => get('/api/cart', auth: true);

  static Future<void> putCart({
    required List<BasketLine> lines,
    required String coupon,
    required String fulfilment,
  }) =>
      put('/api/cart', auth: true, body: {
        'items': lines.map((l) => l.toJson()).toList(),
        'coupon_code': coupon,
        'fulfilment': fulfilment,
      });

  // ---------- Orders ----------
  static Future<Map<String, dynamic>> checkout(Map<String, dynamic> payload) =>
      post('/api/checkout', auth: true, body: payload);

  /// Order tracking is public in the backend, so no auth header is needed.
  static Future<Map<String, dynamic>> order(String id) => get('/api/orders/$id');

  /// History comes straight from Supabase (`orders` + `order_items`) because the
  /// backend only exposes a single-order lookup. Same data the website reads.
  static Future<List<OrderSummary>> myOrders() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const [];
    final rows = await Supabase.instance.client
        .from('orders')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((e) => OrderSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, {this.status});
  @override
  String toString() => message;
}
