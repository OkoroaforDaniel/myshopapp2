import 'package:flutter_test/flutter_test.dart';
import 'package:tandoori_pizza/models.dart';

void main() {
  group('naira', () {
    test('formats like the website N() helper', () {
      expect(naira(0), '\u20a60');
      expect(naira(850), '\u20a6850');
      expect(naira(8500), '\u20a68,500');
      expect(naira(12500), '\u20a612,500');
      expect(naira(15800.4), '\u20a615,800');
    });

    test('handles null', () => expect(naira(null), '\u20a60'));
  });

  group('Product.fromJson', () {
    test('parses integer and string prices (JSONB numbers can arrive either way)', () {
      final p = Product.fromJson({
        'id': '1',
        'name': 'Farm House Xtreme Pizza',
        'description': 'Double chicken.',
        'image_url': 'https://example.com/p.jpg',
        'category': 'Pizzas',
        'prices': {'Regular': 8500, 'Large': '12500', 'Family': 15800.0},
      });
      expect(p.id, '1');
      expect(p.category, 'Pizzas');
      expect(p.prices['Regular'], 8500.0);
      expect(p.prices['Large'], 12500.0);
      expect(p.prices['Family'], 15800.0);
    });

    test('survives a missing prices object', () {
      final p = Product.fromJson({'id': '2', 'name': 'Water'});
      expect(p.prices, isEmpty);
      expect(p.description, '');
    });
  });

  group('BasketLine JSON — must match the shape /api/cart and /api/checkout expect', () {
    test('toJson uses the shared keys', () {
      final line = BasketLine(
        key: '1-Large',
        productId: '1',
        productName: 'Farm House',
        size: 'Large',
        qty: 2,
        unitPrice: 12500,
        imageUrl: 'https://example.com/p.jpg',
      );
      expect(line.toJson(), {
        'product_id': '1',
        'product_name': 'Farm House',
        'size': 'Large',
        'qty': 2,
        'unit_price': 12500.0,
        'image_url': 'https://example.com/p.jpg',
      });
    });

    test('toOrderItem drops image_url for checkout', () {
      final line = BasketLine(
        key: 'k',
        productId: '1',
        productName: 'Farm House',
        size: 'Large',
        qty: 2,
        unitPrice: 12500,
        imageUrl: 'https://example.com/p.jpg',
      );
      expect(line.toOrderItem().containsKey('image_url'), isFalse);
      expect(line.toOrderItem()['qty'], 2);
    });

    test('round-trips a server payload', () {
      final serverItems = [
        {'product_id': '1', 'product_name': 'Farm House', 'size': 'Regular', 'qty': 1, 'unit_price': 8500, 'image_url': ''},
        {'product_id': null, 'product_name': 'Coke', 'size': 'Medium', 'qty': 3, 'unit_price': 500},
      ];
      final lines = [
        for (int i = 0; i < serverItems.length; i++)
          BasketLine.fromJson(Map<String, dynamic>.from(serverItems[i]), index: i),
      ];
      expect(lines.length, 2);
      expect(lines[0].productId, '1');
      expect(lines[0].key, '1-Regular-0');
      expect(lines[1].productId, isNull);
      expect(lines[1].qty, 3);
      expect(lines[1].unitPrice, 500.0);
      expect(lines[1].imageUrl, '');
    });

    test('defaults qty to 1 and size to Medium when fields are missing', () {
      final l = BasketLine.fromJson({'product_name': 'Coke'});
      expect(l.qty, 1);
      expect(l.size, 'Medium');
      expect(l.unitPrice, 0.0);
    });
  });

  group('totals (must match backend COUPONS + 1500 delivery fee)', () {
    final twoLarge = [
      BasketLine(
          key: '1-Large',
          productId: '1',
          productName: 'Farm House',
          size: 'Large',
          qty: 2,
          unitPrice: 12500),
    ];

    test('subtotal 2 x 12,500 = 25,000 + 1,500 delivery', () {
      expect(basketTotal(twoLarge, '', 'Delivery'), 26500);
      expect(basketSubtotal(twoLarge), 25000);
      expect(basketDeliveryFee(twoLarge, 'Delivery'), 1500);
    });

    test('PH3000 takes off 3,000 (any case, trimmed)', () {
      expect(basketTotal(twoLarge, 'ph3000', 'Delivery'), 23500);
      expect(basketTotal(twoLarge, '  PH3000 ', 'Delivery'), 23500);
      expect(couponDiscount('SAVE3'), 3000);
      expect(couponDiscount('WELCOME10'), 2500);
      expect(couponDiscount('FIRST20'), 2000);
    });

    test('Collection means no delivery fee', () {
      expect(basketTotal(twoLarge, '', 'Collection'), 25000);
      expect(basketDeliveryFee(twoLarge, 'Collection'), 0);
    });

    test('an unknown code is ignored', () {
      expect(basketTotal(twoLarge, 'FREEPIZZA', 'Delivery'), 26500);
      expect(couponDiscount(''), 0);
    });

    test('an empty basket has no delivery fee', () {
      expect(basketTotal(const [], '', 'Delivery'), 0);
      expect(basketDeliveryFee(const [], 'Delivery'), 0);
    });

    test('a discount bigger than the basket never returns a negative total', () {
      final small = [
        BasketLine(key: '2-Medium', productName: 'Coke', size: 'Medium', qty: 1, unitPrice: 500),
      ];
      expect(basketTotal(small, 'PH3000', 'Collection'), 0);
    });
  });
}
