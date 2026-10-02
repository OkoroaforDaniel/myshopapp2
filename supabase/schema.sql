-- MyShopApp2 Supabase schema
-- Run this in Supabase Dashboard > SQL Editor

-- PRODUCTS (menu)
create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  category text not null default 'Pizzas',
  name text not null,
  description text default '',
  image_url text default '',
  rating int default 5,
  is_veg boolean default false,
  prices jsonb not null default '{"Small": 21.5, "Medium": 25.9, "Large": 27.9, "XL Large with Sauces": 32.9}',
  created_at timestamptz default now()
);

-- PROFILES (linked to auth.users on google sign-in)
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  avatar_url text,
  created_at timestamptz default now()
);

-- ORDERS
create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  customer_name text not null,
  customer_email text not null,
  phone text default '',
  address text default '',
  city text default '',
  postcode text default '',
  fulfilment text default 'Delivery' check (fulfilment in ('Delivery','Collection')),
  payment_method text default 'Cash on delivery',
  coupon_code text default '',
  free_item text default '',
  subtotal numeric not null default 0,
  discount numeric default 0,
  delivery_fee numeric default 2.5,
  total numeric not null default 0,
  status text default 'pending',
  created_at timestamptz default now()
);

create table if not exists order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete cascade,
  product_id uuid references products(id),
  product_name text not null,
  size text default 'Medium',
  qty int default 1,
  unit_price numeric default 0,
  line_total numeric default 0
);

-- REVIEWS (optional)
create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references products(id),
  author text default 'St Glx',
  location text default 'South London',
  rating int default 5,
  body text default '',
  created_at timestamptz default now()
);

-- Enable RLS
alter table products enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table profiles enable row level security;
alter table reviews enable row level security;

-- Public read for menu
drop policy if exists "public read products" on products;
create policy "public read products" on products for select using (true);
drop policy if exists "public read reviews" on reviews;
create policy "public read reviews" on reviews for select using (true);

-- Orders: allow service_role full access (backend). Allow anon insert for guest checkout:
drop policy if exists "anon insert orders" on orders;
create policy "anon insert orders" on orders for insert with check (true);
drop policy if exists "anon insert order_items" on order_items;
create policy "anon insert order_items" on order_items for insert with check (true);
drop policy if exists "users read own orders" on orders;
create policy "users read own orders" on orders for select using (auth.uid() = user_id or true);

-- Seed menu (Naira prices, Port Harcourt)
-- NOTE: if you already ran the old London seed, run this UPDATE once in SQL Editor:
-- update products set prices = '{"Small": 8500, "Medium": 12500, "Large": 15800, "XL Large with Sauces": 18900}'::jsonb;
insert into products (category, name, description, image_url, is_veg, prices) values
('Pizzas','Farm House Xtreme Pizza','Double chicken, royal cheese, tandoori drizzle, fries crumbs','https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400', false, '{"Regular":8500,"Large":12500,"Family":15800}'),
('Pizzas','Deluxe Pizza','Loaded veggie deluxe with extra mozzarella','https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400', true, '{"Regular":9000,"Large":13000,"Family":16500}'),
('Pizzas','Tandoori Pizza','Smoky tandoori chicken, onions + peppers, raita swirl','https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400', false, '{"Regular":9500,"Large":13500,"Family":17000}'),
('Shawarma','Chicken Shawarma Wrap','Chargrilled chicken, garlic sauce, fries inside','https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=400', false, '{"Regular":3500,"Large":5000,"Family":9500}'),
('Grills & Kebabs','Seekh Kebab Plate','Chargrilled kebabs with naan + onions','https://images.unsplash.com/photo-1603894584373-5ac82b2d3a2d?w=400', false, '{"Regular":6500,"Large":9000,"Family":15000}'),
('Sides','Garlic Bread Supreme','Fresh baked garlic bread with mozzarella','https://images.unsplash.com/photo-1573140247632-f8fd74997d5c?w=400', true, '{"Regular":4000,"Large":5500,"Family":7500}'),
('Drinks','Coca Cola 50cl','Chilled bottle','https://images.unsplash.com/photo-1554866585-cd94860890b7?w=400', true, '{"Regular":1000,"Large":1500,"Family":2000}')
on conflict do nothing;
