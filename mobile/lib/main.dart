import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cart.dart';
import 'config.dart';
import 'screens/account_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/orders_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.supabaseAnonKey.isEmpty) {
    runApp(const _SetupNeededApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  final cart = CartModel();
  await cart.init();

  runApp(TandooriApp(cart: cart));
}

/// Makes the shared [CartModel] available to every screen without pulling in
/// an extra state-management package.
class CartScope extends InheritedNotifier<CartModel> {
  const CartScope({super.key, required CartModel super.notifier, required super.child});

  static CartModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CartScope>();
    assert(scope != null, 'CartScope was not found in the widget tree');
    return scope!.notifier!;
  }
}

class TandooriApp extends StatelessWidget {
  const TandooriApp({super.key, required this.cart});

  final CartModel cart;

  @override
  Widget build(BuildContext context) {
    return CartScope(
      notifier: cart,
      child: MaterialApp(
        title: 'Tandoori Pizza PH',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    final pages = <Widget>[
      HomeScreen(onOpenBasket: () => setState(() => _index = 1)),
      const CartScreen(),
      const OrdersScreen(),
      const AccountScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFE7E0),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.local_pizza_outlined), label: 'Menu'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cart.count > 0,
              label: Text('${cart.count}'),
              child: const Icon(Icons.shopping_basket_outlined),
            ),
            label: 'Basket',
          ),
          const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
          const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
        ],
      ),
    );
  }
}

/// Shown when the Supabase anon key was not passed with --dart-define.
class _SetupNeededApp extends StatelessWidget {
  const _SetupNeededApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.key_outlined, size: 44, color: Brand.brand),
              const SizedBox(height: 16),
              const Text('One setup step left',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text(
                'This build has no Supabase key, so login and live cart sync are off.\n\n'
                'Run the app again with your project keys:\n',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F0F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const SelectableText(
                  'flutter run \\\n'
                  '  --dart-define=SUPABASE_ANON_KEY=your_anon_key',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Get the key from Supabase → Project Settings → API → anon public.',
                style: TextStyle(color: Brand.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
