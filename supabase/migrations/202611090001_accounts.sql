-- SaaS account metadata only. Accommodation records stay in customer Sheets.
create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  business_name text not null default '',
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy "Read own profile" on public.profiles for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Update own profile" on public.profiles for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
grant select, update on public.profiles to authenticated;

create function public.create_customer_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(user_id, display_name, business_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', ''),
    coalesce(new.raw_user_meta_data->>'business_name', ''));
  return new;
end;
$$;
create trigger create_customer_profile after insert on auth.users
  for each row execute function public.create_customer_profile();

create table public.storage_bindings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  google_email text not null,
  spreadsheet_id text not null,
  drive_folder_id text,
  updated_at timestamptz not null default now()
);
alter table public.storage_bindings enable row level security;
create policy "Read own storage" on public.storage_bindings for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Insert own storage" on public.storage_bindings for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Update own storage" on public.storage_bindings for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Delete own storage" on public.storage_bindings for delete to authenticated
  using ((select auth.uid()) = user_id);
grant select, insert, update, delete on public.storage_bindings to authenticated;
