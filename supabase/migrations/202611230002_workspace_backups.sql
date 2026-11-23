do $$
begin
  if to_regclass('public.storage_bindings') is null then
    raise exception using
      message = 'Workspace backups require public.storage_bindings.',
      hint = 'Use the Supabase project configured in SUPABASE_URL. On a new project, apply supabase/migrations/202611090001_accounts.sql first.';
  end if;
end;
$$;

create table public.workspace_backups (
  owner_id uuid primary key references public.storage_bindings(user_id) on delete cascade,
  spreadsheet_id text not null,
  google_email text not null,
  encrypted_refresh_token text not null,
  due_at timestamptz not null default now(),
  dispatched_at timestamptz,
  last_backup_at timestamptz,
  last_file_id text,
  last_error text
);

alter table public.workspace_backups enable row level security;
revoke all on public.workspace_backups from public, anon, authenticated;
grant select, insert, update, delete on public.workspace_backups to service_role;
create index workspace_backups_due on public.workspace_backups(due_at);

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- The worker retries due backups automatically after the dispatch window passes.
select cron.schedule('workspace-backups', '*/15 * * * *', $job$
  with settings as (
    select
      (select decrypted_secret from vault.decrypted_secrets
       where name = 'workspace_backup_project_url') as project_url,
      (select decrypted_secret from vault.decrypted_secrets
       where name = 'workspace_backup_cron_secret') as secret
  ), due as (
    select b.owner_id
    from public.workspace_backups b
    cross join settings s
    where s.project_url is not null and s.secret is not null
      and b.due_at <= now()
      and (b.dispatched_at is null or b.dispatched_at <= now() - interval '1 hour')
    order by b.dispatched_at nulls first, b.due_at
    limit 25
    for update of b skip locked
  ), dispatched as (
    update public.workspace_backups b
    set dispatched_at = now()
    from due
    where b.owner_id = due.owner_id
    returning b.owner_id, b.dispatched_at
  )
  select net.http_post(
    url := rtrim(s.project_url, '/') || '/functions/v1/workspace-backups',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-backup-secret', s.secret),
    body := jsonb_build_object('owner_id', d.owner_id, 'dispatched_at', d.dispatched_at),
    timeout_milliseconds := 140000
  )
  from dispatched d cross join settings s;
$job$);
