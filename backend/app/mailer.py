import httpx
from .config import settings

async def send_email(to: str, subject: str, html: str) -> bool:
    """Send via Mailgun HTTP API. Returns True on success. Never raises."""
    if not settings.MAILGUN_API_KEY or not settings.MAILGUN_DOMAIN:
        print(f"[mailer] skipped (no keys) -> to={to} subject={subject}")
        return False
    url = f"https://api.mailgun.net/v3/{settings.MAILGUN_DOMAIN}/messages"
    try:
        async with httpx.AsyncClient(timeout=15) as c:
            r = await c.post(
                url,
                auth=("api", settings.MAILGUN_API_KEY),
                data={
                    "from": settings.MAILGUN_FROM,
                    "to": to,
                    "subject": subject,
                    "html": html,
                },
            )
            print(f"[mailer] {r.status_code} {r.text[:200]}")
            return r.status_code < 300
    except Exception as e:
        print(f"[mailer] error: {e}")
        return False


def order_email_html(name: str, order_id: str, lines: list[dict], total: float, fulfilment: str) -> str:
    def fmt(v: float) -> str:
        return f"₦{float(v):,.0f}"
    rows = "".join(
        f"<tr><td>{l['qty']}x {l['product_name']} ({l.get('size','')})</td>"
        f"<td align='right'>{fmt(l.get('line_total',0))}</td></tr>"
        for l in lines
    )
    return f"""
    <div style="font-family:Arial,sans-serif;max-width:560px;margin:auto">
      <h2 style="color:#1a1b2e">Thanks {name}! Your order is confirmed 🍕</h2>
      <p>Order <b>#{order_id[:8]}</b> · {fulfilment} · Port Harcourt</p>
      <table width="100%" cellpadding="8" style="border-collapse:collapse">
        {rows}
        <tr><td><b>Total to pay</b></td><td align="right"><b>{fmt(total)}</b></td></tr>
      </table>
      <p>Tandoori Pizza Port Harcourt · 15 Aba Road, GRA · Open daily 9AM–10PM · +234 803 444 4343</p>
    </div>"""
