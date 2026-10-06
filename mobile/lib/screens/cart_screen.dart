import 'package:flutter/material.dart';

import '../cart.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your basket'),
        actions: [
          if (cart.lines.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear basket?'),
                    content: const Text('This also clears the basket on the website.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                    ],
                  ),
                );
                if (ok == true) cart.clear();
              },
              child: const Text('Clear', style: TextStyle(color: Color(0xFFFFC9BC))),
            ),
        ],
      ),
      body: cart.lines.isEmpty ? const _EmptyBasket() : _BasketBody(cart: cart),
    );
  }
}

class _EmptyBasket extends StatelessWidget {
  const _EmptyBasket();

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_basket_outlined, size: 56, color: Brand.muted),
            const SizedBox(height: 14),
            const Text('Your basket is empty',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              cart.isLive
                  ? 'Live sync is on — anything you add on the website shows up here.'
                  : 'Sign in on the Account tab to sync your basket with the website.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Brand.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _BasketBody extends StatelessWidget {
  const _BasketBody({required this.cart});

  final CartModel cart;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _SyncBanner(cart: cart),
        const SizedBox(height: 12),
        for (final line in cart.lines) ...[
          _LineTile(cart: cart, line: line),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        const _SectionTitle('How would you like it?'),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Delivery', label: Text('Delivery'), icon: Icon(Icons.moped_outlined)),
            ButtonSegment(value: 'Collection', label: Text('Collection'), icon: Icon(Icons.storefront_outlined)),
          ],
          selected: {cart.fulfilment},
          onSelectionChanged: (s) => cart.setFulfilment(s.first),
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Discount code'),
        const SizedBox(height: 8),
        _CouponBox(cart: cart),
        const SizedBox(height: 18),
        _Totals(cart: cart),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CheckoutScreen()),
          ),
          icon: const Icon(Icons.arrow_forward),
          label: Text('Checkout · ${naira(cart.total)}'),
        ),
      ],
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.cart});

  final CartModel cart;

  @override
  Widget build(BuildContext context) {
    final live = cart.isLive;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: live ? const Color(0xFFEAF7EF) : const Color(0xFFF1F0F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: live ? const Color(0xFFB9E4CB) : const Color(0xFFE2E0EE)),
      ),
      child: Row(
        children: [
          Icon(live ? Icons.sync : Icons.info_outline,
              size: 18, color: live ? Brand.greenDark : Brand.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              live
                  ? 'Shared with your website basket — changes appear on both in real time.'
                  : 'Local basket. Sign in on the Account tab to share it with the website.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: live ? Brand.greenDark : Brand.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.cart, required this.line});

  final CartModel cart;
  final BasketLine line;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.productName,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text('${line.size} · ${naira(line.unitPrice)} each',
                      style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Text(naira(line.unitPrice * line.qty),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    _RoundBtn(icon: Icons.remove, onTap: () => cart.setQty(line.key, line.qty - 1)),
                    Container(
                      width: 38,
                      alignment: Alignment.center,
                      child: Text('${line.qty}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    _RoundBtn(icon: Icons.add, onTap: () => cart.setQty(line.key, line.qty + 1)),
                  ],
                ),
                TextButton(
                  onPressed: () => cart.setQty(line.key, 0),
                  child: const Text('Remove', style: TextStyle(fontSize: 12, color: Brand.brand)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F0F7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE2E0EE)),
          ),
          child: Icon(icon, size: 17, color: Brand.ink),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5));
}

class _CouponBox extends StatefulWidget {
  const _CouponBox({required this.cart});

  final CartModel cart;

  @override
  State<_CouponBox> createState() => _CouponBoxState();
}

class _CouponBoxState extends State<_CouponBox> {
  late final TextEditingController _ctl = TextEditingController(text: widget.cart.coupon);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _apply() {
    final code = _ctl.text.trim().toUpperCase();
    widget.cart.setCoupon(code);
    final ok = widget.cart.discount > 0;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Code $code applied — you saved ${naira(widget.cart.discount)}'
          : 'Code $code is not valid'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.cart.discount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'e.g. PH3000'),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(onPressed: _apply, child: const Text('Apply')),
          ],
        ),
        if (active)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${widget.cart.coupon} active — saving ${naira(widget.cart.discount)}',
                style: const TextStyle(color: Brand.greenDark, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.cart});

  final CartModel cart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _row('Subtotal (${cart.count} items)', naira(cart.subtotal)),
            if (cart.discount > 0) _row('Discount', '-${naira(cart.discount)}', good: true),
            _row(cart.fulfilment == 'Collection' ? 'Collection' : 'Delivery',
                cart.deliveryFee == 0 ? 'Free' : naira(cart.deliveryFee)),
            const Divider(height: 22),
            Row(
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const Spacer(),
                Text(naira(cart.total),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool good = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: Brand.muted, fontSize: 13)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: good ? Brand.greenDark : Brand.ink,
                )),
          ],
        ),
      );
}
