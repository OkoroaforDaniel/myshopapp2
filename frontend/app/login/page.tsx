'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '../../lib/auth';
export default function LoginPage(){
 const { login, google } = useAuth() as any; const router=useRouter();
 const [email,setEmail]=useState(''); const [password,setPassword]=useState(''); const [err,setErr]=useState(''); const [msg,setMsg]=useState(''); const [loading,setLoading]=useState(false);
 const go=async(e:any)=>{e.preventDefault();setErr('');setMsg('');setLoading(true);try{const r=await login(email,password);if(r?.magic){setMsg('Check your email for a login link.');}else router.push('/');}catch(e:any){setErr(e.message);}finally{setLoading(false);}};
 return(<div className="wrap" style={{maxWidth:460,padding:'30px 20px'}}><div className="card pad"><h2>Welcome back</h2><p style={{color:'#6b7194',fontSize:13}}>Login to track orders and checkout faster. Tip: leave password empty to get a magic email link.</p><button className="btn btn-brand" style={{width:'100%',justifyContent:'center',marginBottom:12}} onClick={google}>Continue with Google</button><form onSubmit={go}><div className="field"><label>Email</label><input value={email} onChange={(e:any)=>setEmail(e.target.value)} required /></div><div className="field"><label>Password (optional for magic link)</label><input type="password" value={password} onChange={(e:any)=>setPassword(e.target.value)} /></div>{err&&<p style={{color:'red'}}>{err}</p>}{msg&&<p style={{color:'green'}}>{msg}</p>}<button className="btn btn-green" style={{width:'100%',justifyContent:'center'}} disabled={loading}>{loading?'Please wait...':'Login'}</button></form><p style={{fontSize:13}}>No account? <a href="/signup" style={{fontWeight:800}}>Sign up</a></p></div></div>);
}
