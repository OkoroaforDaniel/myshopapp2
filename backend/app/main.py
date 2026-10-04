from datetime import datetime, timezone

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from .config import settings
from .schemas import CheckoutRequest, ProfileUpsert, SignupRequest, LoginRequest, CartSyncRequest
from .supabase_client import get_supabase_admin, get_supabase_anon
from .mailer import send_email, order_email_html
from .payments import verify_paystack, send_whatsapp
from .auth import get_user_from_token

app = FastAPI(title="MyShopApp2 API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    # Allow local dev + any Vercel preview/production URL.
    # NOTE: when allow_credentials=True, browsers reject "*" — so we list
    # explicit origins + allow_origin_regex for Vercel.
    allow_origins=[settings.FRONTEND_URL, "http://localhost:3000", "http://127.0.0.1:3000"],
    allow_origin_regex=r"https://.*\.vercel\.app",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {"ok": True, "service": "myshopapp2-backend"}

@app.get("/api/health")
def health():
    return {"ok": True}

# ---------- MENU ----------
@app.get("/api/products")
def list_products(category: str | None = None):
    db = get_supabase_admin()
    q = db.table("products").select("*").order("created_at")
    if category and category != "All":
        q = q.eq("category", category)
    res = q.execute()
    return {"products": res.data or []}

@app.get("/api/categories")
def categories():
    db = get_supabase_admin()
    res = db.table("products").select("category").execute()
    cats = sorted({r["category"] for r in (res.data or []) if r.get("category")})
    return {"categories": cats or ["Pizzas","Garlic Bread","Calzone","Kebabs","Salads","Cold drinks","Happy Meal","Desserts","Hot drinks","Sauces","Orbit"]}

# ---------- AUTH (email/password via Supabase, proxied through backend) ----------
@app.post("/api/auth/signup")
def signup(body: SignupRequest):
    """Create user with Supabase Auth admin API so frontend never needs service key."""
    from supabase import create_client
    if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_KEY:
        raise HTTPException(500, "Supabase not configured")
    admin = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)
    try:
        res = admin.auth.admin.create_user({
            "email": body.email, "password": body.password,
            "email_confirm": True,
            "user_metadata": {"full_name": body.full_name},
        })
        if res.user:
            try:
                get_supabase_admin().table("profiles").upsert({
                    "id": res.user.id, "email": body.email, "full_name": body.full_name,
                }).execute()
            except Exception as e:
                print(f"[profile] {e}")
        return {"ok": True, "user_id": res.user.id if res.user else None}
    except Exception as e:
        raise HTTPException(400, str(e)[:300])


@app.post("/api/auth/login")
def login(body: LoginRequest):
    """Login with email+password. Also supports magic-link (passwordless): pass empty password and we send OTP link."""
    anon = get_supabase_anon()
    try:
        if body.password:
            res = anon.auth.sign_in_with_password({"email": body.email, "password": body.password})
            s = res.session
            return {"ok": True, "access_token": s.access_token if s else None,
                    "user": {"id": res.user.id, "email": res.user.email} if res.user else None}
        # passwordless: send magic link
        anon.auth.sign_in_with_otp({"email": body.email, "options": {"email_redirect_to": settings.FRONTEND_URL}})
        return {"ok": True, "magic_link_sent": True}
    except Exception as e:
        raise HTTPException(401, str(e)[:300])


@app.post("/api/auth/google-url")
def google_url():
    """Return Supabase Google OAuth URL (works once Google provider is enabled in Supabase)."""
    anon = get_supabase_anon()
    try:
        base = (settings.FRONTEND_URL or "http://localhost:3000").rstrip("/")
        redirect_to = f"{base}/auth/callback?next=/"
        res = anon.auth.sign_in_with_oauth({"provider": "google", "options": {"redirect_to": redirect_to}})
        return {"ok": True, "url": res.url, "redirect_to": redirect_to}
    except Exception as e:
        raise HTTPException(400, str(e)[:300])


@app.get("/api/auth/me")
def me(user: dict | None = Depends(get_user_from_token)):
    if not user:
        raise HTTPException(401, "Not logged in")
    return {"ok": True, "user": user}

# ---------- CHECKOUT (Naira) ----------
COUPONS = {"PH3000": 3000.0, "SAVE3": 3000.0, "WELCOME10": 2500.0, "FIRST20": 2000.0}

@app.post("/api/checkout")
async def checkout(body: CheckoutRequest, user: dict | None = Depends(get_user_from_token)):
    if not body.items:
        raise HTTPException(400, "Basket is empty")
    db = get_supabase_admin()

    subtotal = sum(i.qty * float(i.unit_price) for i in body.items)
    discount = COUPONS.get((body.coupon_code or "").upper().strip(), 0.0)
    delivery_fee = 0.0 if body.fulfilment == "Collection" else 1500.0
    total = max(0.0, subtotal - discount + delivery_fee)

    # If Paystack reference supplied, verify it matches total (kobo)
    pay_status = "pending"
    if body.paystack_reference:
        txn = await verify_paystack(body.paystack_reference)
        if not txn:
            raise HTTPException(400, "Paystack payment not verified")
        paid_kobo = int(txn.get("amount", 0))
        if paid_kobo < int(total * 100) - 100:  # allow 1 naira rounding
            raise HTTPException(400, f"Paid ₦{paid_kobo/100:,.0f} but order is ₦{total:,.0f}")
        pay_status = "paid:" + body.paystack_reference

    order_payload = {
        "customer_name": body.customer_name,
        "customer_email": str(body.customer_email),
        "phone": body.phone, "address": body.address,
        "city": body.city, "postcode": body.postcode,
        "fulfilment": body.fulfilment,
        "payment_method": body.payment_method + (f" ({pay_status})" if body.paystack_reference else ""),
        "coupon_code": body.coupon_code, "free_item": body.free_item,
        "subtotal": round(subtotal, 2), "discount": round(discount, 2),
        "delivery_fee": round(delivery_fee, 2), "total": round(total, 2),
        "status": "paid" if body.paystack_reference else "pending",
    }
    if user and user.get("id"):
        order_payload["user_id"] = user["id"]

    created = db.table("orders").insert(order_payload).execute()
    if not created.data:
        raise HTTPException(500, "Could not create order")
    order = created.data[0]

    lines = [
        {"order_id": order["id"], "product_id": it.product_id,
         "product_name": it.product_name, "size": it.size, "qty": it.qty,
         "unit_price": float(it.unit_price),
         "line_total": round(it.qty * float(it.unit_price), 2)}
        for it in body.items
    ]
    db.table("order_items").insert(lines).execute()

    # Confirmation email disabled (Mailgun removed) — customer sees /success page.
    # Order alerts go via WhatsApp below.
    html = order_email_html(body.customer_name, order["id"], lines, total, body.fulfilment)
    await send_email(str(body.customer_email), f"Order confirmed #{order['id'][:8]} — Tandoori Pizza Port Harcourt", html)

    # WhatsApp alert to owner (free via CallMeBot, skipped if not configured)
    item_summary = ", ".join(f"{l['qty']}x {l['product_name']}" for l in lines[:5])
    await send_whatsapp(f"NEW ORDER #{order['id'][:8]} ₦{total:,.0f} — {body.customer_name} {body.phone} — {item_summary} — {body.address}, {body.postcode} — {body.payment_method}")

    return {"ok": True, "order_id": order["id"], "total": round(total, 2),
            "discount": discount, "delivery_fee": delivery_fee}

@app.get("/api/paystack-key")
def paystack_key():
    """Public key for frontend inline payment."""
    return {"public_key": settings.PAYSTACK_PUBLIC_KEY or ""}

# ---------- SHARED CART (web <-> mobile realtime sync) ----------
# One row per user in `carts` table: {user_id, items, coupon_code, fulfilment, updated_at}
# Web + Flutter both read/write here with the SAME Bearer token, so
# "add on web -> instantly on mobile" works via Supabase Realtime.

@app.get("/api/cart")
def get_cart(user: dict | None = Depends(get_user_from_token)):
    if not user:
        raise HTTPException(401, "Login required for synced cart")
    db = get_supabase_admin()
    res = db.table("carts").select("*").eq("user_id", user["id"]).maybe_single().execute()
    row = res.data if hasattr(res, "data") else None
    if not row:
        return {"items": [], "coupon_code": "", "fulfilment": "Delivery"}
    return {"items": row.get("items") or [], "coupon_code": row.get("coupon_code") or "",
            "fulfilment": row.get("fulfilment") or "Delivery",
            "updated_at": row.get("updated_at")}

@app.put("/api/cart")
def put_cart(body: CartSyncRequest, user: dict | None = Depends(get_user_from_token)):
    if not user:
        raise HTTPException(401, "Login required for synced cart")
    db = get_supabase_admin()
    payload = {"user_id": user["id"],
               "items": [i.model_dump() for i in body.items],
               "coupon_code": body.coupon_code or "",
               "fulfilment": body.fulfilment or "Delivery",
               # refreshed on every write so clients can show "last updated by"
               "updated_at": datetime.now(timezone.utc).isoformat()}
    db.table("carts").upsert(payload, on_conflict="user_id").execute()
    return {"ok": True, "items": payload["items"],
            "coupon_code": payload["coupon_code"],
            "fulfilment": payload["fulfilment"],
            "updated_at": payload["updated_at"]}

@app.get("/api/orders/{order_id}")
def get_order(order_id: str):
    db = get_supabase_admin()
    o = db.table("orders").select("*").eq("id", order_id).execute()
    if not o.data:
        raise HTTPException(404, "Order not found")
    items = db.table("order_items").select("*").eq("order_id", order_id).execute()
    return {"order": o.data[0], "items": items.data or []}
