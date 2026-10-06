import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';

/// Order history. Reads the `orders` table straight from Supabase (the same rows
/// the website writes) because the backend only exposes a single-order lookup.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<OrderSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.myOrders();
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() => _future = Api.myOrders());
    });
  }

  Future<void> _refresh() async {
    final f = Api.myOrders();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = Supabase.instance.client.auth.currentUser != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Your orders')),
      body: !signedIn
          ? const _SignInHint()
          : RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<OrderSummary>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Could not load your orders',
                                    style: TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                Text('${snap.error}',
                                    style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                                const SizedBox(height: 12),
                                FilledButton(onPressed: _refresh, child: const Text('Try again')),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  final orders = snap.data ?? const <OrderSummary>[];
                  if (orders.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Text('No orders yet — your first one will show here.',
                              style: TextStyle(color: Brand.muted)),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _OrderCard(order: orders[i]),
                  );
                },
              ),
            ),
    );
  }
}

class _SignInHint extends StatelessWidget {
  const _SignInHint();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Sign in on the Account tab to see your order history.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Brand.muted),
          ),
        ),
      );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderSummary order;

  String get _shortId => order.id.length >= 8 ? order.id.substring(0, 8) : order.id;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#$_shortId',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(width: 8),
                _StatusPill(status: order.status),
                const Spacer(),
                Text(naira(order.total),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 6),
            Text(_prettyDate(order.createdAt),
                style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => _showDetails(context),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('View items'),
            ),
          ],
        ),
      ),
    );
  }

  static String _prettyDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} · ${two(l.hour)}:${two(l.minute)}';
  }

  Future<void> _showDetails(BuildContext parentContext) async {
    await showDialog<void>(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        title: Text('Order #$_shortId'),
        content: SizedBox(
          width: 320,
          child: FutureBuilder<Map<String, dynamic>>(
            future: Api.order(order.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Text('Could not load details: ${snap.error}');
              }
              final items = (snap.data?['items'] as List?) ?? const [];
              if (items.isEmpty) return const Text('No item lines recorded.');
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final raw in items)
                    Builder(builder: (_) {
                      final it = Map<String, dynamic>.from(raw as Map);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${it['qty']}x ${it['product_name']} (${it['size']})',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            Text(
                              naira(double.tryParse('${it['line_total']}') ?? 0),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final paid = status.startsWith('paid');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: paid ? const Color(0xFFEAF7EF) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: paid ? const Color(0xFFB9E4CB) : const Color(0xFFFFDCA8)),
      ),
      child: Text(
        status.isEmpty ? 'pending' : status,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: paid ? Brand.greenDark : const Color(0xFF9A5B00),
        ),
      ),
    );
  }
}
