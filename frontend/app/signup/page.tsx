'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '../../lib/auth';
export default function SignupPage(){
 const { signup, google } = useAuth() as any; const router=useRouter();
 const [name,setName]=useState(''); const [email,setEmail]=useState(''); const [password,setPassword]=useState(''); const [err,setErr]=useState(''); const [loading,setLoading]=useState(false);
 const go=async(e:any)=>{e.preventDefault();setErr('');setLoading(true);try{await signup(name,email,password);router.push('/');}catch(e:any){setErr(e.message);}finally{setLoading(false);}};
 return(<div className="wrap" style={{maxWidth:460,padding:'30px 20px'}}><div className="card pad"><h2>Create account</h2><p style={{color:'#6b7194',fontSize:13}}>One account for ordering, tracking and faster checkout in Port Harcourt.</p><button className="btn btn-brand" style={{width:'100%',justifyContent:'center',marginBottom:12}} onClick={google}>Continue with Google</button><form onSubmit={go}><div className="field"><label>Full name</label><input value={name} onChange={(e:any)=>setName(e.target.value)} required placeholder="Chiamaka Eze" /></div><div className="field"><label>Email</label><input value={email} onChange={(e:any)=>setEmail(e.target.value)} required /></div><div className="field"><label>Password (min 6)</label><input type="password" value={password} onChange={(e:any)=>setPassword(e.target.value)} required minLength={6} /></div>{err&&<p style={{color:'red'}}>{err}</p>}<button className="btn btn-green" style={{width:'100%',justifyContent:'center'}} disabled={loading}>{loading?'Creating...':'Sign up'}</button></form><p style={{fontSize:13}}>Have account? <a href="/login" style={{fontWeight:800}}>Login</a></p></div></div>);
}
