-- Run after the accounts and subscriptions migrations.
alter table public.subscriptions add column admin_blocked boolean not null default false;
create or replace function public.account_access() returns jsonb
language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object(
    'allowed', not suspended and not admin_blocked and greatest(trial_ends_at,coalesce(paid_until,trial_ends_at))>now(),
    'trial_ends_at',trial_ends_at,'paid_until',paid_until,
    'access_until',greatest(trial_ends_at,coalesce(paid_until,trial_ends_at)),
    'server_now',now(),'suspended',suspended or admin_blocked,'billing_cycle',billing_cycle)
  from public.subscriptions where user_id=(select auth.uid());
$$;
create table public.billing_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.billing_admins enable row level security;
revoke all on public.billing_admins from anon, authenticated;
grant all on public.billing_admins to service_role;

create function public.is_billing_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.billing_admins where user_id = (select auth.uid()) and enabled);
$$;
revoke all on function public.is_billing_admin() from public, anon;
grant execute on function public.is_billing_admin() to authenticated;

alter table public.billing_orders add column payment_source text not null default 'paymob'
  check (payment_source in ('paymob','manual'));
alter table public.billing_orders add column payment_reference text;
alter table public.billing_orders add column recorded_by uuid references auth.users(id);
alter table public.billing_orders add column notes text;
create unique index billing_payment_reference on public.billing_orders(payment_source, payment_reference)
  where payment_reference is not null;

create table public.billing_audit (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  actor_user_id uuid references auth.users(id),
  action text not null,
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);
alter table public.billing_audit enable row level security;
revoke all on public.billing_audit from anon, authenticated;
grant all on public.billing_audit to service_role;

create function public.audit_membership_change() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.billing_audit(user_id, actor_user_id, action, details)
    values(new.user_id, auth.uid(), 'membership_changed',
      jsonb_build_object('before', to_jsonb(old), 'after', to_jsonb(new)));
  return new;
end;
$$;
create trigger audit_membership_change after update on public.subscriptions
  for each row when (old.* is distinct from new.*) execute function public.audit_membership_change();

create function public.admin_billing_accounts(p_search text default '', p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_billing_admin() then raise exception 'Billing administrator required' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(to_jsonb(account)) from (
    select u.id as user_id, u.email, u.email_confirmed_at, u.last_sign_in_at,
      u.created_at as registered_at, p.display_name, p.business_name,
      s.trial_ends_at, s.paid_until, s.billing_cycle, s.suspended, s.admin_blocked,
      greatest(s.trial_ends_at,s.paid_until) as next_due_at,
      case when s.user_id is null then 'not_configured'
        when s.suspended or s.admin_blocked then 'blocked'
        when s.paid_until > now() then 'paid'
        when s.trial_ends_at > now() then 'trial'
        else 'unpaid' end as membership_status,
      (select max(o.paid_at) from public.billing_orders o where o.user_id=u.id and o.status='paid') as last_payment_at
    from auth.users u left join public.profiles p on p.user_id=u.id
      left join public.subscriptions s on s.user_id=u.id
    where coalesce(u.email,'') ilike '%' || left(coalesce(p_search,''),100) || '%'
      or coalesce(p.business_name,'') ilike '%' || left(coalesce(p_search,''),100) || '%'
      or coalesce(p.display_name,'') ilike '%' || left(coalesce(p_search,''),100) || '%'
    order by u.created_at desc limit greatest(1,least(coalesce(p_limit,100),500))
  ) account), '[]'::jsonb);
end;
$$;

create function public.admin_customer_billing(p_user_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_billing_admin() then raise exception 'Billing administrator required' using errcode='42501'; end if;
  return jsonb_build_object(
    'payments', coalesce((select jsonb_agg(to_jsonb(payment)) from (
      select id,billing_cycle,amount_cents,currency,mode,status,payment_source,payment_reference,
        transaction_id,paymob_order_id,recorded_by,notes,created_at,paid_at
      from public.billing_orders where user_id=p_user_id order by created_at desc limit 100
    ) payment),'[]'::jsonb),
    'audit', coalesce((select jsonb_agg(to_jsonb(entry)) from (
      select id,actor_user_id,action,details,created_at from public.billing_audit
      where user_id=p_user_id order by created_at desc limit 100
    ) entry),'[]'::jsonb));
end;
$$;

create function public.admin_record_payment(p_user_id uuid, p_billing_cycle text,
  p_amount_cents integer, p_reference text, p_notes text default '')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare anchor timestamptz; ending timestamptz; existing public.billing_orders%rowtype; payment_id uuid;
begin
  if not public.is_billing_admin() then raise exception 'Billing administrator required' using errcode='42501'; end if;
  if p_billing_cycle not in ('monthly','annual') or p_billing_cycle is null then raise exception 'Invalid cycle'; end if;
  if p_amount_cents is null or p_amount_cents < (case when p_billing_cycle='annual' then 54000 else 5000 end)
    then raise exception 'Payment is below the plan base price'; end if;
  if length(trim(coalesce(p_reference,''))) < 3 or length(p_reference)>120 or length(coalesce(p_notes,''))>1000
    then raise exception 'Enter a valid payment reference and notes'; end if;
  -- Serialize the reference across users as well as the membership row.
  perform pg_advisory_xact_lock(hashtextextended('manual-payment:' || trim(p_reference),0));
  select * into existing from public.billing_orders where payment_source='manual' and payment_reference=trim(p_reference);
  if found then
    if existing.user_id<>p_user_id or existing.billing_cycle<>p_billing_cycle or existing.amount_cents<>p_amount_cents then
      raise exception 'Reference already belongs to another payment';
    end if;
    return jsonb_build_object('result','already_recorded','order_id',existing.id);
  end if;
  select greatest(now(),trial_ends_at,coalesce(paid_until,trial_ends_at)) into anchor
    from public.subscriptions where user_id=p_user_id for update;
  if not found then raise exception 'Customer membership is not configured'; end if;
  ending := anchor + case when p_billing_cycle='annual' then interval '1 year' else interval '1 month' end;
  insert into public.billing_orders(user_id,billing_cycle,amount_cents,mode,status,payment_source,payment_reference,recorded_by,notes,paid_at)
    values(p_user_id,p_billing_cycle,p_amount_cents,'live','paid','manual',trim(p_reference),auth.uid(),left(coalesce(p_notes,''),1000),now()) returning id into payment_id;
  update public.subscriptions set paid_until=ending,billing_cycle=p_billing_cycle,suspended=false,admin_blocked=false,updated_at=now() where user_id=p_user_id;
  insert into public.billing_audit(user_id,actor_user_id,action,details) values(p_user_id,auth.uid(),'manual_payment_recorded',
    jsonb_build_object('order_id',payment_id,'reference',trim(p_reference),'amount_cents',p_amount_cents,'access_from',anchor,'access_until',ending));
  return jsonb_build_object('result','payment_recorded','order_id',payment_id,'paid_until',ending);
end;
$$;

create function public.admin_set_membership_block(p_user_id uuid,p_blocked boolean,p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_billing_admin() then raise exception 'Billing administrator required' using errcode='42501'; end if;
  if p_blocked is null or length(trim(coalesce(p_reason,'')))<3 or length(p_reason)>1000 then raise exception 'A reason is required'; end if;
  update public.subscriptions set admin_blocked=p_blocked,updated_at=now() where user_id=p_user_id;
  if not found then raise exception 'Customer membership is not configured'; end if;
  insert into public.billing_audit(user_id,actor_user_id,action,details) values(p_user_id,auth.uid(),
    case when p_blocked then 'manually_blocked' else 'manual_block_removed' end,jsonb_build_object('reason',p_reason));
end;
$$;

-- Customers can read only their own payment history, not private admin notes.
revoke select on public.billing_orders from authenticated;
grant select(id,user_id,billing_cycle,amount_cents,currency,mode,status,payment_source,created_at,paid_at)
  on public.billing_orders to authenticated;
create function public.my_payment_history() returns jsonb
language sql stable security invoker set search_path = '' as $$
  select coalesce(jsonb_agg(to_jsonb(payment)),'[]'::jsonb) from (
    select id,billing_cycle,amount_cents,currency,mode,status,payment_source,created_at,paid_at
    from public.billing_orders where user_id=(select auth.uid()) order by created_at desc limit 100
  ) payment;
$$;

revoke all on function public.admin_billing_accounts(text,integer),public.admin_customer_billing(uuid),
  public.admin_record_payment(uuid,text,integer,text,text),public.admin_set_membership_block(uuid,boolean,text),
  public.my_payment_history() from public,anon;
grant execute on function public.admin_billing_accounts(text,integer),public.admin_customer_billing(uuid),
  public.admin_record_payment(uuid,text,integer,text,text),public.admin_set_membership_block(uuid,boolean,text),
  public.my_payment_history() to authenticated;
notify pgrst,'reload schema';
