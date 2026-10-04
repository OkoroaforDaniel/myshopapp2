-- Run this in Supabase Dashboard > SQL Editor (adds shared web+mobile cart)
create table if not exists carts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  items jsonb not null default '[]',
  coupon_code text default '',
  fulfilment text default 'Delivery',
  updated_at timestamptz default now()
);
alter table carts enable row level security;
drop policy if exists "users own cart" on carts;
create policy "users own cart" on carts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Realtime: let web + mobile receive live changes to each other's cart
alter table carts replica identity full;
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'carts'
  ) then
    alter publication supabase_realtime add table carts;
  end if;
end $$;
