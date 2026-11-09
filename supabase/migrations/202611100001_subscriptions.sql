-- Run after 202611090001_accounts.sql. The browser cannot write entitlements.
create table public.subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  trial_ends_at timestamptz not null,
  paid_until timestamptz,
  billing_cycle text check (billing_cycle in ('monthly', 'annual')),
  suspended boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.subscriptions enable row level security;
create policy "Read own subscription" on public.subscriptions for select to authenticated
  using ((select auth.uid()) = user_id);
revoke all on public.subscriptions from anon, authenticated;
grant select on public.subscriptions to authenticated;

create function public.start_customer_trial() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.subscriptions(user_id, trial_ends_at)
  values(new.id, new.created_at + interval '1 month');
  return new;
end;
$$;
create trigger start_customer_trial after insert on auth.users
  for each row execute function public.start_customer_trial();
insert into public.subscriptions(user_id, trial_ends_at)
  select id, created_at + interval '1 month' from auth.users on conflict do nothing;

create function public.account_access() returns jsonb
language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object(
    'allowed', not suspended and greatest(trial_ends_at, coalesce(paid_until, trial_ends_at)) > now(),
    'trial_ends_at', trial_ends_at, 'paid_until', paid_until,
    'access_until', greatest(trial_ends_at, coalesce(paid_until, trial_ends_at)),
    'server_now', now(), 'suspended', suspended,
    'billing_cycle', billing_cycle)
  from public.subscriptions where user_id = (select auth.uid());
$$;
revoke execute on function public.account_access() from public, anon;
grant execute on function public.account_access() to authenticated;

create function public.has_workspace_access() returns boolean
language sql stable security invoker set search_path = '' as $$
  select coalesce((public.account_access()->>'allowed')::boolean, false);
$$;
revoke execute on function public.has_workspace_access() from public, anon;
grant execute on function public.has_workspace_access() to authenticated;
-- Restrictive policy combines with all existing owner policies.
create policy "Subscription required for storage access" on public.storage_bindings
  as restrictive for all to authenticated
  using (public.has_workspace_access()) with check (public.has_workspace_access());

create table public.billing_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  billing_cycle text not null check (billing_cycle in ('monthly', 'annual')),
  amount_cents integer not null check (amount_cents > 0),
  currency text not null default 'AED' check (currency = 'AED'),
  mode text not null check (mode in ('test', 'live')),
  paymob_order_id text unique,
  transaction_id text unique,
  status text not null default 'pending' check (status in ('pending','failed','paid','refunded')),
  created_at timestamptz not null default now(),
  paid_at timestamptz
);
alter table public.billing_orders enable row level security;
create policy "Read own orders" on public.billing_orders for select to authenticated
  using ((select auth.uid()) = user_id);
revoke all on public.billing_orders from anon, authenticated;
grant select on public.billing_orders to authenticated;
grant all on public.billing_orders, public.subscriptions to service_role;

-- Called only by the signature-verified webhook. Locks make retries/concurrent
-- deliveries idempotent. Never use browser redirect parameters as payment proof.
create function public.settle_paymob_payment(
  p_paymob_order_id text, p_transaction_id text, p_amount_cents integer,
  p_currency text, p_success boolean, p_refunded boolean, p_mode text
) returns text language plpgsql security definer set search_path = '' as $$
declare
  target public.billing_orders%rowtype;
  anchor timestamptz;
begin
  select * into target from public.billing_orders
    where paymob_order_id = p_paymob_order_id for update;
  if not found then raise exception 'Unknown payment order'; end if;
  if target.amount_cents <> p_amount_cents or target.currency <> p_currency or target.mode <> p_mode then
    raise exception 'Payment details do not match order';
  end if;
  if p_refunded then
    if target.transaction_id = p_transaction_id and target.status = 'paid' then
      update public.billing_orders set status = 'refunded' where id = target.id;
      update public.subscriptions set suspended = true, updated_at = now() where user_id = target.user_id;
    end if;
    return 'refund_received';
  end if;
  if target.status in ('paid','refunded') then return 'already_processed'; end if;
  if not p_success then
    update public.billing_orders set status = 'failed' where id = target.id;
    return 'payment_failed';
  end if;
  select greatest(now(), trial_ends_at, coalesce(paid_until, trial_ends_at)) into anchor
    from public.subscriptions where user_id = target.user_id for update;
  if not found then raise exception 'Subscription missing'; end if;
  update public.subscriptions set
    paid_until = anchor + case when target.billing_cycle = 'annual' then interval '1 year' else interval '1 month' end,
    billing_cycle = target.billing_cycle, suspended = false, updated_at = now()
    where user_id = target.user_id;
  update public.billing_orders set status = 'paid', transaction_id = p_transaction_id, paid_at = now() where id = target.id;
  return 'access_extended';
end;
$$;
revoke all on function public.settle_paymob_payment(text,text,integer,text,boolean,boolean,text) from public, anon, authenticated;
grant execute on function public.settle_paymob_payment(text,text,integer,text,boolean,boolean,text) to service_role;
