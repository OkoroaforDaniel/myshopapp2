/// App-wide configuration.
///
/// Values are injected at build/run time so no secrets live in the repo:
///   flutter run --dart-define=SUPABASE_ANON_KEY=xxxx
///
/// The API + Supabase project are the SAME ones the Next.js website uses,
/// which is what makes shared login + shared cart possible.
class AppConfig {
  /// FastAPI backend (Render). Same base URL as the website's NEXT_PUBLIC_API_URL.
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://myshopapp2.onrender.com',
  );

  /// Supabase project (same as the website).
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://igkxhazmaiowtvdxnshw.supabase.co',
  );

  /// Supabase anon (public) key. Safe to ship in a mobile app, but keep it out of git.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Deep link used for Google OAuth. Must be added to Supabase → Auth → URL Configuration.
  static const String oauthRedirect = 'com.tandooripizza.app://login-callback';

  static const String shopCity = 'Port Harcourt';
  static const double deliveryFee = 1500;
}
