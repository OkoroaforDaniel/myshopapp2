import { createClientComponentClient } from '@supabase/auth-helpers-nextjs';
export const supabase = () => createClientComponentClient();
export const N = (v: any) => '₦' + Number(v || 0).toLocaleString('en-NG');
export const API = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';
export async function api(path: string, opts: RequestInit = {}) {
  const r = await fetch(`${API}${path}`, {
    ...opts,
    headers: { 'Content-Type': 'application/json', ...(opts.headers || {}) },
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error((j as any).detail || 'API error');
  return j;
}
export async function apiAuth(path: string, opts: RequestInit = {}) {
  let token = '';
  try {
    const c = createClientComponentClient();
    const { data } = await c.auth.getSession();
    token = data.session?.access_token || '';
  } catch {}
  // Fallback to backend JWT stored by email/password login
  if (!token) { try { token = localStorage.getItem('jwt') || ''; } catch {} }
  if (!token || token === 'null' || token === 'undefined') token = '';
  // Skip Authorization header for guest checkout — backend treats it as guest.
  // Sending a stale/expired token used to cause "Invalid token" 401.
  const headers: any = { ...(opts.headers || {}) };
  if (token) headers.Authorization = `Bearer ${token}`;
  return api(path, { ...opts, headers });
}
export function getSupabaseBrowser() { return createClientComponentClient(); }

