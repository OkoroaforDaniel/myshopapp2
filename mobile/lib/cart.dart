import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api.dart';
import 'models.dart';

/// Basket state that is shared with the website.
///
///  * Guests    → kept locally (SharedPreferences), just like the web keeps
///                its basket in localStorage.
///  * Signed in → mirrored to the `carts` row in Supabase through `/api/cart`,
///                and live-updated via a Realtime subscription. Add a pizza on
///                the website and it appears here in about a second, and the
///                other way round.
class CartModel extends ChangeNotifier {
  static const _kLines = 'basket_v2';
  static const _kCoupon = 'coupon';
  static const _kFulfilment = 'fulfilment';

  List<BasketLine> _lines = [];
  String _coupon = '';
  String _fulfilment = 'Delivery';
  bool _hydrated = false;
  bool _synced = false;
  bool _skipPush = false;

  Timer? _pushTimer;
  RealtimeChannel? _channel;
  SharedPreferences? _prefs;

  List<BasketLine> get lines => _lines;
  String get coupon => _coupon;
  String get fulfilment => _fulfilment;
  bool get hydrated => _hydrated;

  /// True once we know whether we are signed in and, if so, have the server cart.
  bool get synced => _synced;

  /// Drives the "Live" badge in the app bar.
  bool get isLive => _synced && Supabase.instance.client.auth.currentUser != null;

  int get count => _lines.fold(0, (s, l) => s + l.qty);
  double get subtotal => basketSubtotal(_lines);

  double get discount => couponDiscount(_coupon);

  double get deliveryFee => basketDeliveryFee(_lines, _fulfilment);

  double get total => basketTotal(_lines, _coupon, _fulfilment);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadLocal();
    _hydrated = true;
    notifyListeners();

    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      unawaited(_pullAndSubscribe());
    });
    await _pullAndSubscribe();
  }

  void _loadLocal() {
    final p = _prefs;
    if (p == null) return;
    final raw = p.getString(_kLines);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _lines = [
            for (int i = 0; i < decoded.length; i++)
              BasketLine.fromJson(Map<String, dynamic>.from(decoded[i] as Map), index: i)
          ];
        }
      } catch (_) {
        _lines = [];
      }
    }
    _coupon = p.getString(_kCoupon) ?? '';
    _fulfilment = p.getString(_kFulfilment) == 'Collection' ? 'Collection' : 'Delivery';
  }

  Future<void> _persist() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kLines, jsonEncode(_lines.map((l) => l.toJson()).toList()));
    await p.setString(_kCoupon, _coupon);
    await p.setString(_kFulfilment, _fulfilment);
  }

  void _schedulePush() {
    if (!_hydrated || !_synced || _skipPush) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(milliseconds: 600), () => unawaited(_push()));
  }

  Future<void> _push() async {
    if (Supabase.instance.client.auth.currentUser == null) return; // guest: local only
    try {
      await Api.putCart(lines: _lines, coupon: _coupon, fulfilment: _fulfilment);
    } catch (_) {
      // Offline or backend cold-starting — the local basket is still correct.
    }
  }

  Future<void> _pullAndSubscribe() async {
    await _channel?.unsubscribe();
    _channel = null;

    final sb = Supabase.instance.client;
    final user = sb.auth.currentUser;
    if (user == null) {
      _synced = true;
      notifyListeners();
      return;
    }

    try {
      final server = await Api.getCart();
      final items = (server['items'] as List?) ?? const [];
      if (items.isEmpty && _lines.isNotEmpty) {
        // First sign-in with a guest basket: keep it and upload it.
        _synced = true;
        _skipPush = false;
        await _push();
      } else {
        _applyRemote(items, '${server['coupon_code'] ?? ''}', '${server['fulfilment'] ?? ''}');
        await _persist();
      }
    } catch (_) {
      // Backend may still be waking up — the local basket stays usable.
    }

    _synced = true;
    notifyListeners();

    // Live updates: any write from the website (or another phone) lands here.
    _channel = sb
        .channel('cart-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'carts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            final row = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
            final items = row['items'];
            if (items is! List) return;
            _applyRemote(items, '${row['coupon_code'] ?? ''}', '${row['fulfilment'] ?? ''}');
            unawaited(_persist());
          },
        )
        .subscribe();
  }

  /// Applies a remote change without bouncing it straight back to the server.
  void _applyRemote(List<dynamic> items, String coupon, String fulfilment) {
    _skipPush = true;
    _lines = [
      for (int i = 0; i < items.length; i++)
        BasketLine.fromJson(Map<String, dynamic>.from(items[i] as Map), index: i)
    ];
    if (coupon.isNotEmpty) _coupon = coupon;
    if (fulfilment.isNotEmpty) _fulfilment = fulfilment == 'Collection' ? 'Collection' : 'Delivery';
    notifyListeners();
    Timer(const Duration(milliseconds: 900), () => _skipPush = false);
  }

  void add(BasketLine line) {
    final i = _lines.indexWhere((l) => l.key == line.key);
    if (i >= 0) {
      _lines = [..._lines]..[i] = _lines[i].copyWith(qty: _lines[i].qty + line.qty);
    } else {
      _lines = [..._lines, line];
    }
    unawaited(_persist());
    _schedulePush();
    notifyListeners();
  }

  void setQty(String key, int qty) {
    if (qty <= 0) {
      _lines = _lines.where((l) => l.key != key).toList();
    } else {
      _lines = _lines.map((l) => l.key == key ? l.copyWith(qty: qty) : l).toList();
    }
    unawaited(_persist());
    _schedulePush();
    notifyListeners();
  }

  void clear() {
    _lines = [];
    _coupon = '';
    unawaited(_persist());
    _schedulePush();
    notifyListeners();
  }

  void setCoupon(String v) {
    _coupon = v;
    unawaited(_persist());
    _schedulePush();
    notifyListeners();
  }

  void setFulfilment(String v) {
    _fulfilment = v == 'Collection' ? 'Collection' : 'Delivery';
    unawaited(_persist());
    _schedulePush();
    notifyListeners();
  }

  @override
  void dispose() {
    _pushTimer?.cancel();
    unawaited(_channel?.unsubscribe());
    super.dispose();
  }
}
