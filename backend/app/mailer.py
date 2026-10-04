"""Order notifications — email disabled (Mailgun removed).

We keep these helpers as no-ops so the rest of the code doesn't break.
Order alerts now go via WhatsApp (see payments.send_whatsapp).
Customer sees confirmation on the /success page.
"""


async def send_email(to: str, subject: str, html: str) -> bool:
    print(f"[email disabled] to={to} subject={subject} (not sent)")
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
      <h2 style="color:#1a1b2e">Thanks {name}! Your order is confirmed</h2>
      <p>Order <b>#{order_id[:8]}</b> · {fulfilment} · Port Harcourt</p>
      <table width="100%" cellpadding="8" style="border-collapse:collapse">
        {rows}
        <tr><td><b>Total to pay</b></td><td align="right"><b>{fmt(total)}</b></td></tr>
      </table>
      <p>Tandoori Pizza Port Harcourt · GRA · Open daily 9AM-10PM · +234 803 444 4343</p>
    </div>"""
