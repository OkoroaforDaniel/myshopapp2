import './globals.css';
import { CartProvider } from '../lib/cart';
import { AuthProvider } from '../lib/auth';
import HeaderAuth from './header-auth';

export const metadata = { title: 'Tandoori Pizza Port Harcourt — Order Online', description: 'Wood-fired tandoori pizzas, kebabs & more in Port Harcourt. Open daily.' };

export default function RootLayout({ children }: any) {
  return (
    <html lang="en">
      <body>
        <CartProvider>
        <AuthProvider>
          <div className="topbar"><div className="wrap"><span className="dot" /><span>Open now until 10:00 PM · Free delivery over ₦30,000 · Port Harcourt</span></div></div>
          <header className="hdr">
            <div className="wrap hdr-in">
              <a href="/" className="brand"><span className="brand-mark">◍</span><span>Tandoori Pizza<small>PORT HARCOURT · EST. 2012</small></span></a>
              <nav className="nav"><a href="/">Home</a><a href="/#menu" className="hot">Special Offers</a><a href="/checkout">Track Order</a></nav>
              <div className="hdr-act">
                <div className="search"><span>⌕</span><input id="q" placeholder="Search cravings..." /></div>
                <HeaderAuth />
                <a className="btn btn-brand" href="/checkout">Checkout</a>
              </div>
            </div>
          </header>
          {children}
          <footer className="footer">
            <div className="wrap">
              <div className="footer-grid">
                <div><div className="brand" style={{color:'#fff'}}><span className="brand-mark">◍</span><span>Tandoori Pizza<small>TASTE OF INDIA IN PH</small></span></div><p style={{maxWidth:32+'ch',lineHeight:1.6}}>Wood-fired pizzas, chargrilled kebabs and late cravings, delivered hot across Port Harcourt.</p></div>
                <div><h4>Explore</h4>Menu<br/>Special Offers<br/>Track Order<br/>Reviews</div>
                <div><h4>Contact</h4>+234 803 444 4343<br/>orders@tandooripizza.ng<br/>15 Aba Road, GRA Phase 2, Port Harcourt</div>
                <div><h4>Hours</h4>Mon–Sat: 9AM – 10PM<br/>Sun: 12PM – 10PM<br/>Delivery ~30 min</div>
              </div>
              <p style={{opacity:.6,marginTop:22}}>© 2026 Tandoori Pizza Port Harcourt · Crafted with fire</p>
            </div>
          </footer>
          <script dangerouslySetInnerHTML={{__html:`const q=document.getElementById('q');q&&q.addEventListener('input',e=>{window.dispatchEvent(new CustomEvent('search',{detail:e.target.value}))})`}} />
        </AuthProvider>
        </CartProvider>
      </body>
    </html>
  );
}
