# Tandoori Pizza — Flutter mobile app

The phone app for the same shop as the Next.js website in `../frontend`.
Both share **one FastAPI backend** and **one Supabase project**, which is what
makes "add a pizza on the website → it appears on your phone" work.

```
website (Next.js) ─┐
                   ├─► FastAPI (Render) ─► Supabase (products, orders, carts)
app (Flutter)     ─┘
```

## What is already wired up

| Screen | Calls |
| --- | --- |
| Menu | `GET /api/products`, `GET /api/categories` |
| Basket | `GET /api/cart`, `PUT /api/cart` + Supabase Realtime on `carts` |
| Checkout | `POST /api/checkout` |
| Orders | `GET /api/orders/{id}` + Supabase `orders` table for history |
| Account | Supabase Auth: email/password, signup via `POST /api/auth/signup`, Google OAuth |

The shared cart is one row per user:

```sql
carts (user_id uuid primary key, items jsonb, coupon_code text,
       fulfilment text, updated_at timestamptz)
```

* Signed in → the basket is written to `/api/cart` (debounced 600 ms) and every
  client watching that row gets the change instantly through Realtime.
* Signed out → the basket stays on the device (`SharedPreferences`), exactly
  like the website keeps it in `localStorage`.
* Signing in for the first time with a guest basket uploads the local basket
  instead of wiping it.

## 1. One-time setup

### a. Run the cart migration in Supabase

Open **Supabase → SQL Editor** and run the whole of `../supabase/carts-migration.sql`.
It creates the table, the RLS policy, and adds the table to the
`supabase_realtime` publication (that last part is what makes live sync work).

### b. Install Flutter

```bash
brew install --cask flutter     # or: git clone -b stable https://github.com/flutter/flutter.git ~/flutter
flutter doctor
```

To run on a **physical phone** you also need one of:

* **Android** → Android Studio (gives you `adb` + the SDK), or just a debug build
  with `flutter build apk --debug` and sideload it.
* **iPhone** → Xcode from the App Store (macOS), then open `ios/Runner.xcworkspace`
  once to set your signing team.

Want to try it on the phone **right now** without either? Build for the web and
open the URL on the phone — the same Dart code runs:

```bash
flutter run -d chrome --web-port 8080
```

### c. Generate the platform folders (once)

The repo keeps only the Dart source. Generate `android/` + `ios/` in place:

```bash
cd mobile
flutter create --org com.tandooripizza --project-name tandoori_pizza --platforms=android,ios .
flutter pub get
```

`flutter create` never overwrites your `lib/` files, so this is safe to re-run.

### d. Google sign-in redirect (optional)

Google is optional — email + password works out of the box.

1. Supabase → **Authentication → Providers → Google** → enable, paste the client ID/secret.
2. Supabase → **Authentication → URL Configuration → Redirect URLs** → add:
   `com.tandooripizza.app://login-callback`
3. That scheme is declared in `android/app/src/main/AndroidManifest.xml` and
   `ios/Runner/Info.plist` (both created by `flutter create`; add the
   `intent-filter` / `CFBundleURLTypes` entries shown in section 3 below).

## 2. Run it

```bash
cd mobile
flutter run \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key \
  --dart-define=API_URL=https://myshopapp2.onrender.com
```

Get the anon key from **Supabase → Project Settings → API → anon public**.
`SUPABASE_URL` and `API_URL` already default to the live values in
`lib/config.dart`, so you usually only pass the anon key.

Release builds:

```bash
flutter build apk --release --dart-define=SUPABASE_ANON_KEY=...
flutter build ipa --release --dart-define=SUPABASE_ANON_KEY=...
```

## 3. Deep-link entries added by `flutter create`

For Google OAuth to come back into the app:

`android/app/src/main/AndroidManifest.xml`, inside the main `<activity>`:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="com.tandooripizza.app" android:host="login-callback" />
</intent-filter>
```

`ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key><string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array><string>com.tandooripizza.app</string></array>
  </dict>
</array>
```

Also allow cleartext dev traffic is **not** needed — the app talks HTTPS only.

## 4. Project layout

```
lib/
  main.dart                 app shell, bottom navigation, CartScope
  config.dart               API URL, Supabase URL/key, brand constants
  api.dart                  every backend call the app makes
  auth.dart → (in AccountScreen) Supabase auth screens
  cart.dart                 shared basket: local + /api/cart + Realtime
  models.dart               Product / BasketLine / OrderSummary, naira()
  theme.dart                brand colours copied from the website
  screens/
    home_screen.dart        menu, category chips, size picker
    cart_screen.dart        quantities, coupon, Delivery/Collection, totals
    checkout_screen.dart    details → POST /api/checkout
    orders_screen.dart      order history + item detail dialog
    account_screen.dart     login / signup / Google + sync status
```

## 5. Testing the sync end to end

1. Sign in on the **website** in a browser (not as a guest).
2. Add a pizza on the website → the app's basket badge updates within a second.
3. Add a pizza in the **app** → the website basket updates.
4. Open the app's **Account** tab: "Live cart channel" should read `Connected`.
5. If it says `Off`, check that step 1a (the publication line) actually ran:

```sql
select * from pg_publication_tables where pubname = 'supabase_realtime';
```
