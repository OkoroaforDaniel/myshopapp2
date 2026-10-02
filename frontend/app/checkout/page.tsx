'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useCart } from '../../lib/cart';
import { useAuth } from '../../lib/auth';
import { API, apiAuth, N } from '../../lib/api';
export default function CheckoutPage(){
 const cart:any=useCart(); const auth:any=useAuth(); const router=useRouter();
 const [form,setForm]=useState({customer_name:'',customer_email:'',phone:'',address:'',area:'GRA Phase 2',payment_method:'Pay online (Paystack)'});
 const [loading,setLoading]=useState(false); const [err,setErr]=useState(''); const [pk,setPk]=useState('');
 const set=(k:string,v:string)=>setForm((f:any)=>({...f,[k]:v}));
 useEffect(()=>{ if(auth?.user?.email && !form.customer_email) set('customer_email',auth.user.email); },[auth?.user]);
 useEffect(()=>{ fetch(API+'/api/paystack-key').then(r=>r.json()).then(j=>setPk(j.public_key||'')).catch(()=>{}); const s=document.createElement('script'); s.src='https://js.paystack.co/v1/inline.js'; s.async=true; document.body.appendChild(s); return ()=>{try{document.body.removeChild(s);}catch{}}; },[]);
 const placeOrder=async(ref:string)=>{
  setLoading(true); setErr('');
  try{
   if(!cart||cart.lines.length===0) throw new Error('Basket is empty — go back and tap + first.');
   const res=await apiAuth('/api/checkout',{method:'POST',body:JSON.stringify({customer_name:form.customer_name,customer_email:form.customer_email,phone:form.phone,address:form.address,city:'Port Harcourt',postcode:form.area,fulfilment:cart.fulfilment,payment_method:form.payment_method,coupon_code:cart.coupon,free_item:cart.freeItem,paystack_reference:ref||'',items:cart.lines.map((l:any)=>({product_id:l.product_id,product_name:l.product_name,size:l.size,qty:l.qty,unit_price:l.unit_price}))})});
   cart.clear(); router.push('/success?order='+res.order_id+'&total='+res.total);
  }catch(e:any){ setErr(e.message); } finally{ setLoading(false); }
 };

 const submit=(e:any)=>{
  e.preventDefault();
  if(form.payment_method.indexOf('Pay online')===0){
   if(!pk){ setErr('Paystack key missing. Add PAYSTACK_PUBLIC_KEY in backend .env'); return; }
   const W:any=(window as any);
   if(!W.PaystackPop){ setErr('Paystack blocked. Check internet and reload.'); return; }
   const h=W.PaystackPop.setup({key:pk,email:form.customer_email,amount:Math.round(Number(cart.total)*100),currency:'NGN',ref:'PH_'+Date.now(),callback:(r:any)=>placeOrder(r.reference),onClose:()=>setErr('Payment closed. Not charged.')});
   h.openIframe();
  } else placeOrder('');
 };

 if(!cart) return(<div className="wrap">Loading...</div>);
 return(<div className="wrap"><div className="steps"><div className="step on">1 Menu ({cart.count})</div><div className="step on">2 Checkout</div><div className="step">3 Done</div></div><h2>Checkout — PH</h2><p style={{fontSize:13}}>Basket {cart.count} items · Total {N(cart.total)}</p><div className="co-grid"><form className="card pad" onSubmit={submit}><div className="f2"><div className="field"><label>Full name *</label><input required value={form.customer_name} onChange={(e:any)=>set('customer_name',e.target.value)} /></div><div className="field"><label>Email *</label><input required value={form.customer_email} onChange={(e:any)=>set('customer_email',e.target.value)} /></div></div><div className="f2"><div className="field"><label>Phone *</label><input required value={form.phone} onChange={(e:any)=>set('phone',e.target.value)} placeholder="0803 ..." /></div><div className="field"><label>Payment</label><select value={form.payment_method} onChange={(e:any)=>set('payment_method',e.target.value)}><option>Pay online (Paystack)</option><option>Pay on delivery</option><option>Bank transfer</option></select></div></div><div className="field"><label>Address</label><input value={form.address} onChange={(e:any)=>set('address',e.target.value)} placeholder="15 Aba Road" /></div><div className="field"><label>Area</label><select value={form.area} onChange={(e:any)=>set('area',e.target.value)}><option>GRA Phase 2</option><option>D-Line</option><option>Ada George</option><option>Peter Odili</option><option>Choba</option><option>Trans Amadi</option></select></div>{err&&<p style={{color:'red'}}>{err}</p>}<button className="btn btn-green" disabled={loading||cart.lines.length===0} style={{width:'100%',justifyContent:'center'}}>{loading?'Placing...':'Pay '+N(cart.total)}</button></form><div className="card pad"><h3>Summary ({cart.count})</h3>{cart.lines.map((l:any)=>(<div key={l.key} style={{display:'flex',justifyContent:'space-between',fontSize:13}}><span>{l.qty}x {l.product_name}</span><b>{N(l.qty*l.unit_price)}</b></div>))}<div className="grand"><span>Total</span><b>{N(cart.total)}</b></div></div></div></div>);
}
