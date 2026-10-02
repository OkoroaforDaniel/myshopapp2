'use client';
import { useAuth } from '../lib/auth';
export default function HeaderAuth() {
  const { user, logout } = useAuth() as any;
  if (!user) return (<span style={{display:'flex',gap:8}}><a className="btn btn-ghost" href="/login">Login</a><a className="btn btn-accent" href="/signup">Sign up</a></span>);
  return (<span style={{display:'flex',gap:8,alignItems:'center',fontSize:13}}><b>{String(user.email).split('@')[0]}</b><button className="btn btn-ghost" onClick={logout}>Logout</button></span>);
}
