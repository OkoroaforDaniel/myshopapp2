'use client';
import { createContext, useContext, useEffect, useMemo, useState } from 'react';

export type BasketLine = { key: string; product_id?: string; product_name: string; size: string; qty: number; unit_price: number; image_url?: string };

const Ctx = createContext<any>(null);
const KEY = 'basket_v2';

function readBasket(): BasketLine[] {
  try {
    if (typeof window === 'undefined') return [];
    const s = localStorage.getItem(KEY);
    if (s) return JSON.parse(s);
    const old = localStorage.getItem('basket');
    if (old) { const v = JSON.parse(old); localStorage.setItem(KEY, JSON.stringify(v)); return v; }
    return [];
  } catch { return []; }
}

export function CartProvider({ children }: any) {
  // Lazy init from localStorage — no load/save race, no wipe on navigation
  const [lines, setLinesState] = useState<BasketLine[]>(() => readBasket());
  const [coupon, setCouponState] = useState(() => { try { return localStorage.getItem('coupon') || ''; } catch { return ''; } });
  const [freeItem, setFreeItem] = useState('');
  const [fulfilment, setFulfilmentState] = useState<'Delivery'|'Collection'>(() => {
    try { const f = localStorage.getItem('fulfilment'); return (f === 'Collection' ? 'Collection' : 'Delivery'); } catch { return 'Delivery'; }
  });
  const [hydrated, setHydrated] = useState(false);
  useEffect(() => {
    // Re-read after hydration (covers SSR + stale state after navigation)
    setLinesState(readBasket());
    setHydrated(true);
  }, []);

  const persist = (next: BasketLine[]) => { try { localStorage.setItem(KEY, JSON.stringify(next)); } catch {} };

  const add = (l: BasketLine) => setLinesState(prev => {
    const i = prev.findIndex(p => p.key === l.key);
    const next = i >= 0 ? prev.map((p, idx) => (idx === i ? { ...p, qty: p.qty + l.qty } : p)) : [...prev, l];
    persist(next);
    return next;
  });
  const setQty = (key: string, qty: number) => setLinesState(prev => {
    const next = qty <= 0 ? prev.filter(p => p.key !== key) : prev.map(p => (p.key === key ? { ...p, qty } : p));
    persist(next);
    return next;
  });
  const clear = () => { setLinesState([]); try { localStorage.removeItem(KEY); localStorage.removeItem('basket'); } catch {} };
  const setCoupon = (v: string) => { setCouponState(v); try { localStorage.setItem('coupon', v); } catch {} };
  const setFulfilment = (v: 'Delivery' | 'Collection') => { setFulfilmentState(v); try { localStorage.setItem('fulfilment', v); } catch {} };

  const subtotal = useMemo(() => lines.reduce((s, l) => s + l.qty * Number(l.unit_price || 0), 0), [lines]);
  const discount = useMemo(() => { const c = (coupon || '').trim().toUpperCase(); return c === 'PH3000' || c === 'SAVE3' ? 3000 : c === 'WELCOME10' ? 2500 : c === 'FIRST20' ? 2000 : 0; }, [coupon]);
  const deliveryFee = lines.length === 0 ? 0 : (fulfilment === 'Collection' ? 0 : 1500);
  const total = Math.max(0, subtotal - discount + deliveryFee);
  const count = lines.reduce((s, l) => s + l.qty, 0);

  // Avoid hydration mismatch: server renders 0, client has real basket.
  // Render basket-dependent numbers only after hydration.
  const display = (v: any) => (hydrated ? v : 0);

  return <Ctx.Provider value={{ lines: hydrated ? lines : [], add, setQty, clear, coupon, setCoupon, freeItem, setFreeItem, fulfilment, setFulfilment, subtotal: display(subtotal), discount: display(discount), deliveryFee: display(deliveryFee), total: display(total), hydrated, count: display(count) }}>{children}</Ctx.Provider>;
}
export const useCart = () => useContext(Ctx);


