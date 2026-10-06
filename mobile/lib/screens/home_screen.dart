import 'package:flutter/material.dart';

import '../api.dart';
import '../cart.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';

/// Menu screen — calls the same `/api/products` + `/api/categories` as the site.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenBasket});

  final VoidCallback onOpenBasket;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _fallbackCats = <String>[
    'Pizzas',
    'Shawarma',
    'Grills & Kebabs',
    'Burgers',
    'Drinks',
    'Sides',
  ];

  List<String> _cats = _fallbackCats;
  String _active = 'Pizzas';
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  final _searchCtl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _loadCats();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadCats() async {
    try {
      final cats = await Api.categories();
      if (cats.isNotEmpty && mounted) setState(() => _cats = cats);
    } catch (_) {
      // Keep the fallback chips if the backend is cold-starting.
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Api.products(category: _active);
      if (mounted) setState(() => _products = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Product> get _filtered {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return _products;
    // Token search across name + description + category.
    // "tandoori pizza" -> both words must appear SOMEWHERE (not necessarily
    // next to each other), so it matches "Farm House Xtreme Pizza" whose
    // description has "tandoori". Handles plurals: "pizzas" matches "pizza".
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return _products.where((p) {
      final hay = '${p.name} ${p.description} ${p.category}'.toLowerCase();
      return words.every((w) {
        if (hay.contains(w)) return true;
        // singular fallback: "pizzas" -> "pizza"
        if (w.endsWith('s') && w.length > 3 && hay.contains(w.substring(0, w.length - 1))) {
          return true;
        }
        return false;
      });
    }).toList();
  }

  Future<void> _addProduct(Product p) async {
    final cart = CartScope.of(context);
    if (p.prices.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${p.name} has no sizes set yet.')));
      return;
    }
    final picked = await showModalBottomSheet<MapEntry<String, double>>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _SizeSheet(product: p, sizes: p.prices.entries.toList()),
    );
    if (picked == null || !mounted) return;

    cart.add(BasketLine(
      key: '${p.id}-${picked.key}',
      productId: p.id,
      productName: p.name,
      size: picked.key,
      qty: 1,
      unitPrice: picked.value,
      imageUrl: p.imageUrl,
    ));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${p.name} (${picked.key}) added'),
      duration: const Duration(seconds: 2),
      action: SnackBarAction(
        label: 'Basket',
        textColor: Brand.amber,
        onPressed: widget.onOpenBasket,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: const LinearGradient(colors: [Brand.brand, Color(0xFFFF8A3C)]),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.local_pizza, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tandoori Pizza',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.1)),
                Text('Port Harcourt',
                    style: TextStyle(color: Color(0xFFC9CBE0), fontSize: 11, height: 1.3)),
              ],
            ),
          ],
        ),
        actions: [
          if (cart.isLive)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1B3A26),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF2E7D4F)),
              ),
              child: const Row(
                children: [
                  _LiveDot(),
                  SizedBox(width: 6),
                  Text('Live cart',
                      style: TextStyle(
                          color: Color(0xFF7CE0A3), fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _hero(cart),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Search the menu…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 14),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = _cats[i];
                  final on = c == _active;
                  return ChoiceChip(
                    label: Text(c),
                    selected: on,
                    onSelected: (_) {
                      setState(() => _active = c);
                      _loadProducts();
                    },
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : Brand.ink,
                      fontSize: 13,
                    ),
                    selectedColor: Brand.ink,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFECEAF3)),
                    shape: const StadiumBorder(),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _errorCard()
            else if (_filtered.isEmpty)
              _emptyCard()
            else
              // FIX: give each card an intrinsic height (unbounded ListView +
              // stretch Row + network image with no height = zero-height cards).
              Column(
                children: [
                  for (final p in _filtered) ...[
                    SizedBox(
                      height: 132,
                      child: _ProductCard(
                          product: p, onAdd: () => _addProduct(p)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFECEAF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nothing in this category yet (v3).',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'Backend returned ${_products.length} items for "$_active". '
              'Try another chip (e.g. Shawarma) or tap Try again.',
              style: const TextStyle(color: Brand.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      );

  Widget _errorCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Could not load the menu',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadProducts, child: const Text('Try again')),
            ],
          ),
        ),
      );

  Widget _hero(CartModel cart) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Brand.heroStart, Brand.heroEnd],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: const Text('OPEN NOW IN PH',
                  style: TextStyle(
                      color: Color(0xFFFFD9C7),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Port Harcourt cravings,\nwood-fired in minutes.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tandoori pizzas, shawarma and grills delivered hot across GRA, Ada George and Peter Odili.',
              style: TextStyle(color: Color(0xFFC9CBE0), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton(
                  onPressed: widget.onOpenBasket,
                  child: Text(cart.count == 0
                      ? 'Start your order'
                      : 'Basket · ${naira(cart.total)}'),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text('Code PH3000 = \u20a63,000 off',
                      style: TextStyle(
                          color: Color(0xFFFFD9C7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      );
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: .35, end: 1).animate(_c),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
        ),
      );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onAdd});

  final Product product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final first = product.prices.values.isEmpty ? 0.0 : product.prices.values.first;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 104,
            child: product.imageUrl.isEmpty
                ? Container(color: const Color(0xFFF1F0F7), child: const Icon(Icons.local_pizza))
                : Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF1F0F7),
                      child: const Icon(Icons.local_pizza),
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  const SizedBox(height: 4),
                  Text(product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('from ${naira(first)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SizeSheet extends StatelessWidget {
  const _SizeSheet({required this.product, required this.sizes});

  final Product product;
  final List<MapEntry<String, double>> sizes;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 2),
            const Text('Pick a size', style: TextStyle(color: Brand.muted, fontSize: 13)),
            const SizedBox(height: 14),
            for (final e in sizes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).pop(e),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFECEAF3)),
                      color: const Color(0xFFFAFAFC),
                    ),
                    child: Row(
                      children: [
                        Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text(naira(e.value), style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(width: 10),
                        const Icon(Icons.add_circle, color: Brand.brand),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
