'use client';
import { createContext, useContext, useEffect, useState } from 'react';
import { API, supabase } from './api';

const Ctx = createContext<any>(null);

export function AuthProvider({ children }: any) {
  const [user, setUser] = useState<any>(null);
  const [token, setToken] = useState('');
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const sb = supabase();
    const doInit = async () => {
      // Fallback: if Supabase sent us to /?code=... (old backend URL), exchange it here
      try {
        const params = new URLSearchParams(window.location.search);
        const code = params.get('code');
        if (code) {
          try { await (sb.auth as any).exchangeCodeForSession(code); } catch {}
          window.history.replaceState({}, '', window.location.pathname);
        }
      } catch {}
      const { data }: any = await sb.auth.getSession();
      setToken(data.session?.access_token || localStorage.getItem('jwt') || '');
      setUser(data.session?.user || JSON.parse(localStorage.getItem('user') || 'null'));
      setReady(true);
    };
    doInit();
    const { data: sub } = sb.auth.onAuthStateChange((_e: any, s: any) => {
      if (s) {
        setToken(s.access_token); setUser(s.user);
        localStorage.setItem('jwt', s.access_token); localStorage.setItem('user', JSON.stringify(s.user));
        // sync profile to backend (best-effort)
        fetch(`${API}/api/auth/profile`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${s.access_token}` }, body: JSON.stringify({ email: s.user.email, full_name: s.user.user_metadata?.full_name || '', avatar_url: '' }) }).catch(() => {});
      }
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  const signup = async (full_name: string, email: string, password: string) => {
    const r = await fetch(`${API}/api/auth/signup`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ full_name, email, password }) });
    const j = await r.json();
    if (!r.ok) throw new Error(j.detail || 'Signup failed');
    // auto-login after signup
    return login(email, password);
  };
  const login = async (email: string, password: string) => {
    if (!password) {
      // magic link
      const r = await fetch(`${API}/api/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email }) });
      const j = await r.json();
      if (!r.ok) throw new Error(j.detail || 'Login failed');
      return { magic: true };
    }
    const r = await fetch(`${API}/api/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
    const j = await r.json();
    if (!r.ok) throw new Error(j.detail || 'Login failed');
    if (j.access_token) {
      localStorage.setItem('jwt', j.access_token); localStorage.setItem('user', JSON.stringify(j.user));
      setToken(j.access_token); setUser(j.user);
      // set supabase session so Google + backend JWT stay in sync
      try { const sb = supabase(); await sb.auth.setSession({ access_token: j.access_token, refresh_token: '' } as any); } catch {}
    }
    return j;
  };
  const google = async () => {
    // IMPORTANT: must generate URL with the JS client (not backend),
    // so PKCE verifier is stored in browser cookies for /auth/callback to exchange.
    const sb = supabase();
    const redirectTo = `${window.location.origin}/auth/callback?next=/`;
    const { error } = await sb.auth.signInWithOAuth({ provider: 'google', options: { redirectTo } });
    if (error) alert('Google login failed: ' + error.message);
  };
  const logout = async () => {
    try { await supabase().auth.signOut(); } catch {}
    localStorage.removeItem('jwt'); localStorage.removeItem('user');
    setToken(''); setUser(null);
  };

  return <Ctx.Provider value={{ user, token, ready, signup, login, google, logout }}>{children}</Ctx.Provider>;
}
export const useAuth = () => useContext(Ctx);
