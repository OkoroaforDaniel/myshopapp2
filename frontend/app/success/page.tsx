'use client';
import { useSearchParams } from 'next/navigation';
import { Suspense } from 'react';
import { N } from '../../lib/api';
function Inner(){
 const q=useSearchParams();
 return(<div className="wrap" style={{padding:40,textAlign:'center'}}><h1>Thank you! Order received.</h1><p>Order <b>#{String(q.get('order')||'').slice(0,8)}</b> confirmed.</p><p>Total: <b>{N(q.get('total'))}</b></p><p>We will call you shortly. Delivery across Port Harcourt in 30-45 mins.</p><a href="/" className="btn btn-green">Back to shop</a></div>);
}
export default function Success(){return(<Suspense><Inner/></Suspense>);}
