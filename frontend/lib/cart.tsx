'use client';
import { createContext, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { apiAuth, supabase } from './api';

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

// --- shape used by GET/PUT /api/cart (shared with the Flutter mobile app) ---
function toSync(lines: BasketLine[]) {
  return lines.map(l => ({
    product_id: l.product_id || null,
    product_name: l.product_name,
    size: l.size || 'Medium',
    qty: Number(l.qty || 0),
    unit_price: Number(l.unit_price || 0),
    image_url: l.image_url || '',
  }));
}
function fromSync(items: any[]): BasketLine[] {
  return (items || []).map((l: any, i: number) => ({
    key: `${l.product_id || l.product_name}-${l.size || 'Medium'}-${i}`,
    product_id: l.product_id || undefined,
    product_name: l.product_name,
    size: l.size || 'Medium',
    qty: Number(l.qty || 1),
    unit_price: Number(l.unit_price || 0),
    image_url: l.image_url || '',
  }));
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
  const [synced, setSynced] = useState(false); // true once we know auth state for sync
  const [authTick, setAuthTick] = useState(0); // bumped on login/logout so we re-pull the shared cart
  const pushTimer = useRef<any>(null);
  const skipPush = useRef(false); // guard: don't echo remote changes back to the server

  useEffect(() => {
    const sb = supabase();
    const { data: sub } = sb.auth.onAuthStateChange(() => setAuthTick(t => t + 1));
    return () => sub.subscription.unsubscribe();
  }, []);
  useEffect(() => {
    // Re-read after hydration (covers SSR + stale state after navigation)
    setLinesState(readBasket());
    setHydrated(true);
  }, []);

  const persist = (next: BasketLine[]) => { try { localStorage.setItem(KEY, JSON.stringify(next)); } catch {} };

  // ---- realtime sync: web <-> mobile share one `carts` row per user ----
  const push = async (next: BasketLine[], c: string, f: string) => {
    try {
      const sb = supabase(); const { data } = await sb.auth.getSession();
      if (!data.session?.access_token) return; // guest: stays local-only
      await apiAuth('/api/cart', { method: 'PUT', body: JSON.stringify({ items: toSync(next), coupon_code: c || '', fulfilment: f || 'Delivery' }) });
    } catch { /* offline / not logged in — local basket still works */ }
  };
  const schedulePush = (next: BasketLine[], c: string = coupon, f: string = fulfilment) => {
    if (!hydrated || !synced) return;
    clearTimeout(pushTimer.current);
    pushTimer.current = setTimeout(() => push(next, c, f), 600); // debounce rapid taps
  };

  // Initial pull + Supabase Realtime subscription so a change made on the
  // phone (Flutter) shows up here instantly, and vice-versa.
  useEffect(() => {
    if (!hydrated) return;
    let chan: any = null;
    (async () => {
      try {
        const sb = supabase(); const { data } = await sb.auth.getSession();
        const uid = data.session?.user?.id;
        if (!uid) { setSynced(true); return; } // guest checkout: local only
        try {
          const srv: any = await apiAuth('/api/cart');
          if (srv && Array.isArray(srv.items)) {
            const local = readBasket();
            if (srv.items.length === 0 && local.length > 0) {
              // First sign-in with a guest basket: adopt the local one instead of wiping it.
              schedulePush(local, localStorage.getItem('coupon') || '', localStorage.getItem('fulfilment') || 'Delivery');
            } else {
              skipPush.current = true;
              const merged = fromSync(srv.items);
              setLinesState(merged); persist(merged);
              if (srv.coupon_code) { setCouponState(srv.coupon_code); try { localStorage.setItem('coupon', srv.coupon_code); } catch {} }
              if (srv.fulfilment) { setFulfilmentState(srv.fulfilment); try { localStorage.setItem('fulfilment', srv.fulfilment); } catch {} }
              setTimeout(() => { skipPush.current = false; }, 800);
            }
          }
        } catch { /* backend cart not ready yet */ }
        setSynced(true);
        chan = sb.channel('cart-' + uid)
          .on('postgres_changes', { event: '*', schema: 'public', table: 'carts', filter: `user_id=eq.${uid}` }, (p: any) => {
            const row = p?.new || p?.record;
            if (!row || !Array.isArray(row.items)) return;
            skipPush.current = true;
            const merged = fromSync(row.items);
            setLinesState(merged); persist(merged);
            setTimeout(() => { skipPush.current = false; }, 800);
          })
          .subscribe();
      } catch { setSynced(true); }
    })();
    return () => { try { if (chan) supabase().removeChannel(chan); } catch {} };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hydrated, authTick]);

  const applyAndSync = (next: BasketLine[]) => {
    persist(next);
    if (!skipPush.current) schedulePush(next);
    return next;
  };

  const add = (l: BasketLine) => setLinesState(prev => {
    const i = prev.findIndex(p => p.key === l.key);
    const next = i >= 0 ? prev.map((p, idx) => (idx === i ? { ...p, qty: p.qty + l.qty } : p)) : [...prev, l];
    return applyAndSync(next);
  });
  const setQty = (key: string, qty: number) => setLinesState(prev => {
    const next = qty <= 0 ? prev.filter(p => p.key !== key) : prev.map(p => (p.key === key ? { ...p, qty } : p));
    return applyAndSync(next);
  });
  const clear = () => {
    setLinesState([]);
    try { localStorage.removeItem(KEY); localStorage.removeItem('basket'); } catch {}
    if (!skipPush.current) schedulePush([]);
  };
  const setCoupon = (v: string) => {
    setCouponState(v); try { localStorage.setItem('coupon', v); } catch {}
    if (!skipPush.current) schedulePush(lines, v);
  };
  const setFulfilment = (v: 'Delivery' | 'Collection') => {
    setFulfilmentState(v); try { localStorage.setItem('fulfilment', v); } catch {}
    if (!skipPush.current) schedulePush(lines, coupon, v);
  };

  const subtotal = useMemo(() => lines.reduce((s, l) => s + l.qty * Number(l.unit_price || 0), 0), [lines]);
  const discount = useMemo(() => { const c = (coupon || '').trim().toUpperCase(); return c === 'PH3000' || c === 'SAVE3' ? 3000 : c === 'WELCOME10' ? 2500 : c === 'FIRST20' ? 2000 : 0; }, [coupon]);
  const deliveryFee = lines.length === 0 ? 0 : (fulfilment === 'Collection' ? 0 : 1500);
  const total = Math.max(0, subtotal - discount + deliveryFee);
  const count = lines.reduce((s, l) => s + l.qty, 0);

  // Avoid hydration mismatch: server renders 0, client has real basket.
  // Render basket-dependent numbers only after hydration.
  const display = (v: any) => (hydrated ? v : 0);

  return <Ctx.Provider value={{ lines: hydrated ? lines : [], add, setQty, clear, coupon, setCoupon, freeItem, setFreeItem, fulfilment, setFulfilment, subtotal: display(subtotal), discount: display(discount), deliveryFee: display(deliveryFee), total: display(total), hydrated, count: display(count), synced }}>{children}</Ctx.Provider>;
}
export const useCart = () => useContext(Ctx);


