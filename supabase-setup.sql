-- ============================================================
-- FX LOGISTICS — SUPABASE SCHEMA
-- Run this once in: Supabase Dashboard → SQL Editor → New query
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- SHIPMENTS ----------
create table if not exists shipments (
  id uuid primary key default gen_random_uuid(),
  tracking_number text unique not null,
  origin text,
  destination text,
  recipient text,
  mode text default 'Ocean Freight',
  status text default 'Order Received',
  eta date,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ---------- SHIPMENT TRACKING UPDATES (timeline events) ----------
create table if not exists shipment_updates (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid references shipments(id) on delete cascade,
  event_date date not null,
  location text,
  note text,
  created_at timestamptz default now()
);

-- ---------- QUOTE / CONTACT ENQUIRIES ----------
create table if not exists quote_requests (
  id uuid primary key default gen_random_uuid(),
  request_type text default 'quote',           -- 'quote' or 'contact'
  full_name text not null,
  email text not null,
  phone text,
  company text,
  service_type text,                            -- Ocean / Air / Warehousing / Customs / General
  origin text,
  destination text,
  cargo_description text,
  weight_kg numeric,
  volume_cbm numeric,
  preferred_mode text,
  notes text,
  handled boolean default false,
  created_at timestamptz default now()
);

-- ---------- keep updated_at fresh on shipments ----------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_shipments_updated_at on shipments;
create trigger trg_shipments_updated_at
before update on shipments
for each row execute function set_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table shipments enable row level security;
alter table shipment_updates enable row level security;
alter table quote_requests enable row level security;

-- Anyone (customers, using the anon key) can look up shipments to track them
drop policy if exists "Public can view shipments" on shipments;
create policy "Public can view shipments"
  on shipments for select
  using (true);

drop policy if exists "Public can view shipment updates" on shipment_updates;
create policy "Public can view shipment updates"
  on shipment_updates for select
  using (true);

-- Anyone can submit a quote/contact enquiry, but cannot read enquiries back
drop policy if exists "Public can submit enquiries" on quote_requests;
create policy "Public can submit enquiries"
  on quote_requests for insert
  with check (true);

-- Logged-in staff (any authenticated Supabase Auth user) can manage everything
drop policy if exists "Staff manage shipments" on shipments;
create policy "Staff manage shipments"
  on shipments for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists "Staff manage shipment updates" on shipment_updates;
create policy "Staff manage shipment updates"
  on shipment_updates for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists "Staff read enquiries" on quote_requests;
create policy "Staff read enquiries"
  on quote_requests for select
  using (auth.role() = 'authenticated');

drop policy if exists "Staff update enquiries" on quote_requests;
create policy "Staff update enquiries"
  on quote_requests for update
  using (auth.role() = 'authenticated');

-- ============================================================
-- SEED DATA (safe to delete later from the staff portal)
-- ============================================================
insert into shipments (tracking_number, origin, destination, recipient, mode, status, eta)
values
  ('FX82619614', 'Guangzhou, China', 'Lagos, Nigeria', 'Chidi Okonkwo', 'Ocean Freight', 'In Transit', '2026-07-14'),
  ('FX40213877', 'London, United Kingdom', 'Ibadan, Nigeria', 'Funmi Adebayo', 'Air Freight', 'Delivered', '2026-06-18'),
  ('FX55927301', 'New York, USA', 'Ikeja, Lagos, Nigeria', 'Emeka Nwosu', 'Air Freight', 'Customs Clearance', '2026-07-08')
on conflict (tracking_number) do nothing;

insert into shipment_updates (shipment_id, event_date, location, note)
select id, '2026-06-20', 'Guangzhou, China', 'Order received at origin warehouse' from shipments where tracking_number = 'FX82619614'
union all
select id, '2026-06-24', 'Guangzhou Port, China', 'Departed origin port' from shipments where tracking_number = 'FX82619614'
union all
select id, '2026-07-02', 'At Sea', 'In transit toward Lagos' from shipments where tracking_number = 'FX82619614'
union all
select id, '2026-06-10', 'London, UK', 'Order received at origin warehouse' from shipments where tracking_number = 'FX40213877'
union all
select id, '2026-06-15', 'Lagos, Nigeria', 'Cleared Nigerian customs' from shipments where tracking_number = 'FX40213877'
union all
select id, '2026-06-18', 'Ibadan, Nigeria', 'Delivered to recipient' from shipments where tracking_number = 'FX40213877'
union all
select id, '2026-06-28', 'New York, USA', 'Order received at origin warehouse' from shipments where tracking_number = 'FX55927301'
union all
select id, '2026-07-03', 'Murtala Muhammed Airport, Lagos', 'Arrived Nigeria, undergoing customs clearance' from shipments where tracking_number = 'FX55927301';
