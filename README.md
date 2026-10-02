# MyShopApp2 — Tandoori Pizza London shop
# Frontend: Next.js (Vercel) · Backend: FastAPI (Render) · DB+Auth: Supabase · Email: Mailgun

## 1) Supabase (database + Google auth store)
1. Create project at https://supabase.com → get `SUPABASE_URL`, `anon key`, `service_role key`, `JWT secret` (Project Settings → API).
2. SQL Editor → paste & run `supabase/schema.sql` (creates products/orders/order_items/profiles + seed menu).
3. Authentication → Providers → enable **Google**:
   - Google Cloud Console → https://console.cloud.google.com → New project → APIs & Services → Credentials → Create **OAuth client ID** (Web) → Authorized redirect URI = `https://<your-supabase-ref>.supabase.co/auth/v1/callback`
   - Copy Client ID + Secret into Supabase Google provider. Also add Site URL = your Vercel URL + `http://localhost:3000`.
4. Auth → URL Configuration → add Redirect URLs: `http://localhost:3000/**`, `https://<vercel-app>/**`.

## 2) Mailgun (confirmation emails)
1. https://mailgun.com → add domain (or use sandbox for testing) → get `MAILGUN_API_KEY` + `MAILGUN_DOMAIN`.
2. For sandbox: authorize recipient emails first. For live: verify DNS, use `orders@yourdomain.com` as FROM.
3. Backend env: `MAILGUN_API_KEY`, `MAILGUN_DOMAIN`, `MAILGUN_FROM`, `SHOP_OWNER_EMAIL`.

## 3) Run locally (how frontend ↔ backend ↔ DB connect)
```
Backend (FastAPI → Supabase via service key):
  cd backend && cp .env.example .env   # fill keys
  pip install -r requirements.txt
  uvicorn app.main:app --reload --port 8000   # docs at http://localhost:8000/docs

Frontend (Next.js → Backend via NEXT_PUBLIC_API_URL, → Supabase Auth directly):
  cd frontend && cp .env.example .env.local   # NEXT_PUBLIC_API_URL=http://localhost:8000
  npm install && npm run dev                  # http://localhost:3000
```
Flow: `page.tsx (menu)` fetches `GET {API}/api/products` → FastAPI reads Supabase `products`. `checkout/page.tsx` posts to `POST {API}/api/checkout` → FastAPI inserts `orders`+`order_items` → sends Mailgun emails. Google button uses `supabase.auth.signInWithOAuth({provider:'google'})` (needs Google Cloud client id configured in Supabase), token sent as `Bearer` to backend which verifies JWT and links `user_id`.

## 4) Deploy — frontend on Vercel
1. Push repo to GitHub. Vercel → New Project → Root Directory = `frontend`.
2. Env vars: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_API_URL=https://<your-render-api>.onrender.com`.
3. Deploy. Add Vercel URL to Supabase redirect URLs.

## 5) Deploy — backend on Render (yes, possible)
1. Render → New → Web Service → connect repo → Root Directory = `backend`.
2. Build: `pip install -r requirements.txt` · Start: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`.
3. Env vars: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY`, `SUPABASE_JWT_SECRET`, `MAILGUN_API_KEY`, `MAILGUN_DOMAIN`, `MAILGUN_FROM`, `SHOP_OWNER_EMAIL`, `FRONTEND_URL=https://<vercel-app>`.
4. After deploy, set Vercel `NEXT_PUBLIC_API_URL` to the Render URL and redeploy frontend. Test `https://<render>/api/health`.

## 6) Checkout test
Add pizza sizes → basket → Checkout → fill form → Pay → redirected to `/success?order=...` → check Supabase `orders` table + inbox for Mailgun email. Coupons: `SAVE3`, `WELCOME10`, `FIRST20`.

## Files
- `frontend/` Next.js shop matching moodboard (menu/basket/info/reviews/checkout/success)
- `backend/app/` FastAPI: `/api/products`, `/api/categories`, `/api/checkout`, `/api/orders/{id}`, `/api/auth/profile`
- `supabase/schema.sql` tables + seed
