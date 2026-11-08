-- Debt Cure Dashboard schema (namespaced dcd_*)
create table if not exists public.dcd_cards (
  id text primary key,
  name text not null,
  mask text not null default '',
  balance_cents integer not null default 0,
  limit_cents integer,
  apr numeric(5,2),
  apr_estimated boolean not null default false,
  days_late_label text not null default '',
  status text not null default 'delinquent',
  charge_off_date date,
  cure_amount_cents integer,
  cure_label text,
  phone text,
  note text,
  urgency_rank integer not null default 99,
  sort_order integer not null default 0,
  cured_at timestamptz
);

create table if not exists public.dcd_action_items (
  id text primary key,
  phase integer not null,
  title text not null,
  detail text,
  done boolean not null default false,
  done_at timestamptz,
  sort_order integer not null default 0
);

create table if not exists public.dcd_payments (
  id uuid primary key default gen_random_uuid(),
  card_id text references public.dcd_cards(id) on delete cascade,
  amount_cents integer not null,
  kind text not null default 'avalanche',
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.dcd_goals (
  id text primary key,
  name text not null,
  target_cents integer not null,
  saved_cents integer not null default 0,
  note text,
  sort_order integer not null default 0
);

create table if not exists public.dcd_profile (
  key text primary key,
  value jsonb not null
);

alter table public.dcd_cards enable row level security;
alter table public.dcd_action_items enable row level security;
alter table public.dcd_payments enable row level security;
alter table public.dcd_goals enable row level security;
alter table public.dcd_profile enable row level security;

create policy dcd_cards_anon on public.dcd_cards for all using (true) with check (true);
create policy dcd_action_items_anon on public.dcd_action_items for all using (true) with check (true);
create policy dcd_payments_anon on public.dcd_payments for all using (true) with check (true);
create policy dcd_goals_anon on public.dcd_goals for all using (true) with check (true);
create policy dcd_profile_anon on public.dcd_profile for all using (true) with check (true);
