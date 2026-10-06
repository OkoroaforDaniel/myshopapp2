import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api.dart';
import '../config.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';

/// Account tab: login / signup / Google, plus the sync status of the shared cart.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  bool _signupMode = false;
  bool _busy = false;
  String? _error;
  String? _info;

  SupabaseClient get _sb => Supabase.instance.client;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    if (_signupMode && password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (!_signupMode && password.isEmpty) {
      setState(() => _error = 'Enter your password');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final name = _name.text.trim();
      if (_signupMode) {
        // Use the backend admin endpoint so the account is created pre-confirmed,
        // exactly like the website's signup does.
        await Api.post('/api/auth/signup', body: {
          'email': email,
          'password': password,
          'full_name': name.isEmpty ? email.split('@').first : name,
        });
      }
      // Works for both flows: same Supabase project as the website, so an
      // account created on the site logs straight in here.
      await _sb.auth.signInWithPassword(email: email, password: password);
      if (mounted) {
        setState(() {
          _info = _signupMode ? 'Welcome! Your basket is now shared.' : 'Signed in — basket synced.';
          _signupMode = false;
          _password.clear();
        });
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await _sb.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConfig.oauthRedirect,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (mounted) setState(() => _info = 'Finish signing in with Google, then come back.');
    } on AuthException catch (e) {
      setState(() => _error =
          '${e.message}\n\nGoogle sign-in needs the redirect URL ${AppConfig.oauthRedirect} added in Supabase → Authentication → URL Configuration.');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await _sb.auth.signOut();
      if (mounted) setState(() => _info = 'Signed out. Basket is local again.');
    } catch (_) {
      // ignore — session already gone
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _sb.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (user == null) ..._signedOut() else ..._signedIn(user),
          const SizedBox(height: 22),
          const _StatusCard(),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How the shared cart works',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                  const SizedBox(height: 8),
                  _bullet('The app and the website talk to the same backend (${AppConfig.apiUrl}).'),
                  _bullet('Signing in uses the same Supabase account, so one login works on both.'),
                  _bullet('Your basket lives in one shared row per user — change it here or on the '
                      'web and both update live.'),
                  _bullet('Guests keep a local basket; it is uploaded the first time they sign in.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _signedIn(User user) => [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFFFE7E0),
                  child: Text(
                    (user.email ?? '?').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 20, color: Brand.brand),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Signed in',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Brand.muted)),
                      const SizedBox(height: 1),
                      Text(user.email ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.check_circle, size: 15, color: Brand.green),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text('Basket shared with the website',
                                style: TextStyle(
                                    color: Brand.greenDark, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _busy ? null : _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ];

  List<Widget> _signedOut() => [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_signupMode ? 'Create your account' : 'Sign in',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 4),
                const Text(
                  'Sign in to share your basket with the website and see your orders here.',
                  style: TextStyle(color: Brand.muted, fontSize: 12.5),
                ),
                if (_signupMode) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Full name'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(hintText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: _signupMode ? 'Password (6+ characters)' : 'Password',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12.5)),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 12),
                  Text(_info!, style: const TextStyle(color: Brand.greenDark, fontSize: 12.5)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submitEmail,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Text(_signupMode ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _google,
                  icon: const Icon(Icons.g_mobiledata, size: 26),
                  label: const Text('Continue with Google'),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _signupMode = !_signupMode;
                      _error = null;
                      _info = null;
                    }),
                    child: Text(_signupMode
                        ? 'Already have an account? Sign in'
                        : 'New here? Create an account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ];

  Widget _bullet(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 5, right: 8),
              child: Icon(Icons.circle, size: 6, color: Brand.muted),
            ),
            Expanded(
              child: Text(t, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            ),
          ],
        ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    final signedIn = Supabase.instance.client.auth.currentUser != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sync status',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            const SizedBox(height: 10),
            _line('Signed in', signedIn ? 'Yes' : 'No'),
            _line('Live cart channel', cart.isLive ? 'Connected' : 'Off'),
            _line('Basket items', '${cart.count}'),
            _line('Basket total', naira(cart.total)),
          ],
        ),
      ),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(k, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
            const Spacer(),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          ],
        ),
      );
}
