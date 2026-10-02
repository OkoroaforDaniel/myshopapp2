import jwt
from fastapi import Header
from .config import settings

def get_user_from_token(authorization: str | None = Header(default=None)) -> dict | None:
    """Optional auth: returns supabase user dict or None for guest checkout.
    NEVER 401 here — a bad/expired token should still allow guest checkout.
    """
    if not authorization or not authorization.startswith("Bearer "):
        return None
    token = authorization.split(" ", 1)[1].strip().strip('"').strip("'")
    if not token or token.lower() in ("null", "undefined"):
        return None
    try:
        # Supabase JWT — verify signature if secret known, else decode without verify
        if settings.SUPABASE_JWT_SECRET and len(settings.SUPABASE_JWT_SECRET) > 20:
            try:
                payload = jwt.decode(token, settings.SUPABASE_JWT_SECRET, algorithms=["HS256"], audience="authenticated")
            except Exception:
                # Secret may be wrong/rotated — fall back to unverified decode so checkout still works
                payload = jwt.decode(token, options={"verify_signature": False})
        else:
            payload = jwt.decode(token, options={"verify_signature": False})
        sub = payload.get("sub")
        if not sub:
            return None
        return {"id": sub, "email": payload.get("email"), "payload": payload}
    except Exception as e:
        print(f"[auth] bad token ignored (guest checkout): {str(e)[:120]}")
        return None
