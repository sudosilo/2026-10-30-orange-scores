-- MobbyHill accounts, token wallets, paid credits and permanent unlocks.
-- Only the score hub server reaches these, with the service role key. The public keys get nothing.
create extension if not exists pgcrypto;

create table if not exists mh_accounts (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  pass_hash text not null,
  created_at timestamptz not null default now()
);
create table if not exists mh_wallets (
  user_id uuid primary key references mh_accounts(id) on delete cascade,
  tokens integer not null default 0 check (tokens >= 0),
  last_cycle integer not null default -1
);
create table if not exists mh_unlocks (
  user_id uuid not null references mh_accounts(id) on delete cascade,
  item text not null,
  price integer not null,
  created_at timestamptz not null default now(),
  primary key (user_id, item)
);
create table if not exists mh_payments (
  session_id text primary key,
  user_id uuid not null references mh_accounts(id) on delete cascade,
  tokens integer not null,
  amount_cents integer not null,
  created_at timestamptz not null default now()
);
create table if not exists mh_spends (
  id bigserial primary key,
  user_id uuid not null references mh_accounts(id) on delete cascade,
  item text not null,
  price integer not null,
  created_at timestamptz not null default now()
);

alter table mh_accounts enable row level security;
alter table mh_wallets enable row level security;
alter table mh_unlocks enable row level security;
alter table mh_payments enable row level security;
alter table mh_spends enable row level security;
revoke all on mh_accounts, mh_wallets, mh_unlocks, mh_payments, mh_spends from anon, authenticated;

create or replace function mh_signup(p_name text, p_hash text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  insert into mh_accounts(name, pass_hash) values (p_name, p_hash) on conflict (name) do nothing returning id into v;
  if v is not null then insert into mh_wallets(user_id) values (v); end if;
  return v;
end $$;

create or replace function mh_login(p_name text) returns table(id uuid, pass_hash text)
language sql security definer set search_path = public as $$
  select a.id, a.pass_hash from mh_accounts a where a.name = p_name;
$$;

-- Adds the weekly grant once per cycle, up to the cap. Bought tokens are never capped.
create or replace function mh_state(p_uid uuid, p_cycle integer, p_grant integer, p_cap integer) returns json
language plpgsql security definer set search_path = public as $$
declare w mh_wallets; g integer := 0;
begin
  insert into mh_wallets(user_id) values (p_uid) on conflict do nothing;
  select * into w from mh_wallets where user_id = p_uid for update;
  if w.last_cycle < p_cycle then
    g := greatest(0, least(p_cap, w.tokens + p_grant) - w.tokens);
    update mh_wallets set tokens = tokens + g, last_cycle = p_cycle where user_id = p_uid returning * into w;
  end if;
  return json_build_object('ok', true, 'tokens', w.tokens, 'granted', g,
    'unlocks', coalesce((select json_agg(u.item order by u.item) from mh_unlocks u where u.user_id = p_uid), '[]'::json));
end $$;

-- Takes tokens in one step. Kept items (vehicles and parts) go into mh_unlocks and are never charged twice.
create or replace function mh_spend(p_uid uuid, p_item text, p_price integer, p_keep boolean) returns json
language plpgsql security definer set search_path = public as $$
declare t integer;
begin
  select tokens into t from mh_wallets where user_id = p_uid for update;
  if not found then return json_build_object('ok', false, 'error', 'no_wallet', 'tokens', 0); end if;
  if p_keep and exists (select 1 from mh_unlocks where user_id = p_uid and item = p_item) then
    return json_build_object('ok', true, 'owned', true, 'tokens', t);
  end if;
  if t < p_price then return json_build_object('ok', false, 'error', 'not_enough_tokens', 'tokens', t); end if;
  update mh_wallets set tokens = tokens - p_price where user_id = p_uid returning tokens into t;
  insert into mh_spends(user_id, item, price) values (p_uid, p_item, p_price);
  if p_keep then insert into mh_unlocks(user_id, item, price) values (p_uid, p_item, p_price); end if;
  return json_build_object('ok', true, 'tokens', t);
end $$;

-- Credits a paid Stripe checkout once. A repeated webhook for the same session adds nothing.
create or replace function mh_credit(p_session text, p_uid uuid, p_tokens integer, p_cents integer) returns json
language plpgsql security definer set search_path = public as $$
begin
  insert into mh_payments(session_id, user_id, tokens, amount_cents) values (p_session, p_uid, p_tokens, p_cents)
    on conflict (session_id) do nothing;
  if not found then return json_build_object('ok', true, 'duplicate', true); end if;
  insert into mh_wallets(user_id) values (p_uid) on conflict do nothing;
  update mh_wallets set tokens = tokens + p_tokens where user_id = p_uid;
  return json_build_object('ok', true, 'duplicate', false);
end $$;

revoke all on function mh_signup(text, text) from public, anon, authenticated;
revoke all on function mh_login(text) from public, anon, authenticated;
revoke all on function mh_state(uuid, integer, integer, integer) from public, anon, authenticated;
revoke all on function mh_spend(uuid, text, integer, boolean) from public, anon, authenticated;
revoke all on function mh_credit(text, uuid, integer, integer) from public, anon, authenticated;
grant execute on function mh_signup(text, text) to service_role;
grant execute on function mh_login(text) to service_role;
grant execute on function mh_state(uuid, integer, integer, integer) to service_role;
grant execute on function mh_spend(uuid, text, integer, boolean) to service_role;
grant execute on function mh_credit(text, uuid, integer, integer) to service_role;
