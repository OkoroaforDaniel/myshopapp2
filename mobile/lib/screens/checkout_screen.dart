import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';

/// Checkout — posts to the same `/api/checkout` the website uses, so orders
/// show up in the same dashboard / WhatsApp alert / order list.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _areas = [
    'GRA Phase 2',
    'D-Line',
    'Ada George',
    'Peter Odili',
    'Choba',
    'Trans Amadi',
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  String _area = _areas.first;
  String _payment = 'Pay on delivery';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata;
    _email.text = user?.email ?? '';
    _name.text = '${meta?['full_name'] ?? meta?['name'] ?? ''}';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final cart = CartScope.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (cart.lines.isEmpty) {
      setState(() => _error = 'Your basket is empty.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await Api.checkout({
        'customer_name': _name.text.trim(),
        'customer_email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'city': 'Port Harcourt',
        'postcode': _area,
        'fulfilment': cart.fulfilment,
        'payment_method': _payment,
        'coupon_code': cart.coupon,
        'free_item': '',
        'paystack_reference': '',
        'items': cart.lines.map((l) => l.toOrderItem()).toList(),
      });
      final orderId = '${res['order_id'] ?? ''}';
      final total = (res['total'] as num?)?.toDouble() ?? cart.total;
      cart.clear();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Order placed 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order #${orderId.length >= 8 ? orderId.substring(0, 8) : orderId}'),
              const SizedBox(height: 6),
              Text('Total ${naira(total)} · $_payment'),
              const SizedBox(height: 6),
              const Text(
                'We will call you to confirm. Payment is collected on delivery.',
                style: TextStyle(color: Brand.muted, fontSize: 12.5),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F0F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 18, color: Brand.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${cart.count} items · ${naira(cart.total)} · ${cart.fulfilment}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _label('Full name *'),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Chidi Okeke'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
            ),
            const SizedBox(height: 14),
            _label('Email *'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'you@example.com'),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Please enter an email';
                if (!s.contains('@') || !s.contains('.')) return 'That email looks wrong';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _label('Phone *'),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '0803 000 0000'),
              validator: (v) =>
                  (v == null || v.replaceAll(RegExp(r'\D'), '').length < 7)
                      ? 'Please enter a reachable phone number'
                      : null,
            ),
            const SizedBox(height: 14),
            _label('Delivery address'),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(hintText: '15 Aba Road, flat 2'),
            ),
            const SizedBox(height: 14),
            _label('Area'),
            DropdownButtonFormField<String>(
              initialValue: _area,
              items: [for (final a in _areas) DropdownMenuItem(value: a, child: Text(a))],
              onChanged: (v) => setState(() => _area = v ?? _areas.first),
            ),
            const SizedBox(height: 14),
            _label('Payment'),
            DropdownButtonFormField<String>(
              initialValue: _payment,
              items: const [
                DropdownMenuItem(value: 'Pay on delivery', child: Text('Pay on delivery')),
                DropdownMenuItem(value: 'Bank transfer', child: Text('Bank transfer')),
                DropdownMenuItem(value: 'Pay online (Paystack)', child: Text('Pay online (Paystack)')),
              ],
              onChanged: (v) => setState(() => _payment = v ?? 'Pay on delivery'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Card payment on mobile is coming next — Pay on delivery and bank transfer work today.',
              style: TextStyle(color: Brand.muted, fontSize: 12),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF5C6C0)),
                ),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12.5)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _placeOrder,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text('Place order · ${naira(cart.total)}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Brand.ink)),
      );
}
