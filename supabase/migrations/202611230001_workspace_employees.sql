create table public.workspace_employees (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  email text not null check (email = lower(trim(email))),
  employee_id uuid references auth.users(id) on delete set null,
  permissions text[] not null check (
    cardinality(permissions) > 0 and permissions <@
    array['occupancy', 'bookings', 'collect_rent', 'payment_history', 'void_payments']::text[]
    and (not ('void_payments' = any(permissions)) or 'payment_history' = any(permissions))
  ),
  unique (owner_id, email)
);
create index workspace_employees_member on public.workspace_employees(employee_id);

create table public.workspace_employee_connections (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  spreadsheet_id text not null,
  google_email text not null,
  encrypted_refresh_token text not null
);

create table public.workspace_employee_activity (
  owner_id uuid not null references auth.users(id) on delete cascade,
  operation_id uuid not null,
  employee_email text not null,
  action text not null,
  details jsonb not null,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (owner_id, operation_id)
);

alter table public.workspace_employees enable row level security;
alter table public.workspace_employee_connections enable row level security;
alter table public.workspace_employee_activity enable row level security;
revoke all on public.workspace_employees, public.workspace_employee_connections,
  public.workspace_employee_activity from public, anon, authenticated;
grant select, insert, update, delete on public.workspace_employees,
  public.workspace_employee_connections, public.workspace_employee_activity to service_role;

create table public.workspace_employee_write_locks (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  operation_id uuid not null,
  expires_at timestamptz not null default now() + interval '2 minutes'
);
alter table public.workspace_employee_write_locks enable row level security;
revoke all on public.workspace_employee_write_locks from public, anon, authenticated;
grant select, insert, update, delete on public.workspace_employee_write_locks to service_role;

create function public.acquire_employee_write_lock(workspace_owner uuid, operation uuid)
returns boolean language sql set search_path = '' as $$
  with acquired as (
    insert into public.workspace_employee_write_locks(owner_id, operation_id)
      values (workspace_owner, operation)
    on conflict (owner_id) do update
      set operation_id = excluded.operation_id, expires_at = excluded.expires_at
      where workspace_employee_write_locks.expires_at <= now()
    returning owner_id
  )
  select exists(select 1 from acquired);
$$;
revoke execute on function public.acquire_employee_write_lock(uuid, uuid) from public, anon, authenticated;
grant execute on function public.acquire_employee_write_lock(uuid, uuid) to service_role;
