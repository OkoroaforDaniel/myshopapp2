import 'dart:convert';

import 'config.dart';

/// Naira formatter identical to the website's `N()` helper.
String naira(num? v) {
  final n = (v ?? 0).round();
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '\u20a6${buf.toString()}';
}

class Product {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String category;
  final Map<String, double> prices;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.prices,
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    final raw = (j['prices'] is Map) ? Map<String, dynamic>.from(j['prices']) : <String, dynamic>{};
    return Product(
      id: '${j['id'] ?? ''}',
      name: '${j['name'] ?? ''}',
      description: '${j['description'] ?? ''}',
      imageUrl: '${j['image_url'] ?? ''}',
      category: '${j['category'] ?? ''}',
      prices: raw.map((k, v) => MapEntry(k, _toDouble(v))),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }
}

/// One line of the basket. The same JSON shape is stored in Supabase `carts.items`
/// and POSTed to `/api/checkout`, so the web and the app agree byte-for-byte.
class BasketLine {
  final String key;
  final String? productId;
  final String productName;
  final String size;
  final int qty;
  final double unitPrice;
  final String imageUrl;

  BasketLine({
    required this.key,
    this.productId,
    required this.productName,
    required this.size,
    required this.qty,
    required this.unitPrice,
    this.imageUrl = '',
  });

  BasketLine copyWith({int? qty}) => BasketLine(
        key: key,
        productId: productId,
        productName: productName,
        size: size,
        qty: qty ?? this.qty,
        unitPrice: unitPrice,
        imageUrl: imageUrl,
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'size': size,
        'qty': qty,
        'unit_price': unitPrice,
        'image_url': imageUrl,
      };

  /// Shape sent to /api/checkout (image_url not needed there).
  Map<String, dynamic> toOrderItem() => {
        'product_id': productId,
        'product_name': productName,
        'size': size,
        'qty': qty,
        'unit_price': unitPrice,
      };

  factory BasketLine.fromJson(Map<String, dynamic> j, {int index = 0}) {
    final pid = j['product_id'];
    final name = '${j['product_name'] ?? ''}';
    final size = '${j['size'] ?? 'Medium'}';
    return BasketLine(
      key: '${pid ?? name}-$size-$index',
      productId: (pid == null || '$pid'.isEmpty) ? null : '$pid',
      productName: name,
      size: size,
      qty: int.tryParse('${j['qty'] ?? 1}') ?? 1,
      unitPrice: Product._toDouble(j['unit_price']),
      imageUrl: '${j['image_url'] ?? ''}',
    );
  }
}

class OrderSummary {
  final String id;
  final double total;
  final String status;
  final String createdAt;
  final List<Map<String, dynamic>> items;

  OrderSummary({
    required this.id,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> j) {
    final itemsRaw = j['items'];
    return OrderSummary(
      id: '${j['id'] ?? ''}',
      total: Product._toDouble(j['total']),
      status: '${j['status'] ?? ''}',
      createdAt: '${j['created_at'] ?? ''}',
      items: itemsRaw is List
          ? itemsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[],
    );
  }
}

String prettyJson(Object o) => const JsonEncoder.withIndent('  ').convert(o);

// ---------------------------------------------------------------------------
// Pricing — kept as pure functions so they are unit-testable and so the mobile
// totals can never drift from the backend's `COUPONS` dict + 1500 delivery fee.
// ---------------------------------------------------------------------------

const Map<String, double> couponValues = {
  'PH3000': 3000.0,
  'SAVE3': 3000.0,
  'WELCOME10': 2500.0,
  'FIRST20': 2000.0,
};

double couponDiscount(String code) => couponValues[code.trim().toUpperCase()] ?? 0;

double basketSubtotal(List<BasketLine> lines) =>
    lines.fold<double>(0, (s, l) => s + l.qty * l.unitPrice);

double basketDeliveryFee(List<BasketLine> lines, String fulfilment) {
  if (lines.isEmpty) return 0;
  return fulfilment == 'Collection' ? 0 : AppConfig.deliveryFee;
}

double basketTotal(List<BasketLine> lines, String coupon, String fulfilment) {
  final t = basketSubtotal(lines) - couponDiscount(coupon) + basketDeliveryFee(lines, fulfilment);
  return t < 0 ? 0 : t;
}
