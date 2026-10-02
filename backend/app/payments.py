import httpx
from .config import settings

async def verify_paystack(reference: str) -> dict | None:
    """Verify a Paystack transaction. Returns txn dict or None. Amount is in kobo."""
    if not settings.PAYSTACK_SECRET_KEY or not reference:
        return None
    try:
        async with httpx.AsyncClient(timeout=15) as c:
            r = await c.get(
                f"https://api.paystack.co/transaction/verify/{reference}",
                headers={"Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}"},
            )
            j = r.json()
            if r.status_code == 200 and j.get("status") and j.get("data", {}).get("status") == "success":
                return j["data"]
            print(f"[paystack] verify failed: {j}")
            return None
    except Exception as e:
        print(f"[paystack] error: {e}")
        return None


async def send_whatsapp(text: str) -> bool:
    """Free WhatsApp alert via CallMeBot. Setup: message 'I allow callmebot to send me messages' to +34 644 10 55 84 on WhatsApp, get apikey at https://www.callmebot.com/blog/free-api-whatsapp-messages/"""
    if not settings.WHATSAPP_PHONE or not settings.WHATSAPP_APIKEY:
        print(f"[whatsapp] skipped (no keys): {text[:120]}")
        return False
    try:
        import urllib.parse
        url = f"https://api.callmebot.com/whatsapp.php?phone={settings.WHATSAPP_PHONE}&text={urllib.parse.quote(text[:1000])}&apikey={settings.WHATSAPP_APIKEY}"
        async with httpx.AsyncClient(timeout=15) as c:
            r = await c.get(url)
            print(f"[whatsapp] {r.status_code} {r.text[:120]}")
            return r.status_code == 200
    except Exception as e:
        print(f"[whatsapp] error: {e}")
        return False
