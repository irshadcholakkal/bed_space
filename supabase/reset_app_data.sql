-- MANUAL DESTRUCTIVE RESET for project wyojharbgdxtiobwxvbf.
-- Run in Supabase SQL Editor only when all app data and Auth users can be deleted.
-- Removes profiles, workspace links, subscriptions, billing history, and admins.
-- Preserves schema, policies, functions, OAuth configuration, and Google files.
-- This is deliberately outside migrations so deployments never run it.

begin;

-- Include only app tables installed by this project's migrations. Use one
-- TRUNCATE so foreign keys between present app tables are handled together.
-- No CASCADE: unexpected dependencies stop the reset.
do $$
declare
  target_name text;
  targets text[] := array[]::text[];
begin
  foreach target_name in array array[
    'billing_audit', 'billing_orders', 'billing_admins',
    'storage_bindings', 'subscriptions', 'profiles'
  ] loop
    if to_regclass(format('public.%I', target_name)) is not null then
      targets := array_append(targets, format('public.%I', target_name));
    end if;
  end loop;
  if cardinality(targets) > 0 then
    execute 'truncate table ' || array_to_string(targets, ', ');
  end if;
end;
$$;

-- Supabase Auth's dependent identities and sessions are removed by its schema.
-- Existing Storage ownership or other dependencies may block this deletion;
-- in that case the transaction aborts and the app-table reset is rolled back.
delete from auth.users;

commit;

-- Verify present tables and explicitly report migrations not installed.
create temporary table reset_counts (
  table_name text, remaining bigint, status text
);
do $$
declare
  target_name text;
  row_count bigint;
begin
  foreach target_name in array array[
    'auth.users', 'public.profiles', 'public.storage_bindings',
    'public.subscriptions', 'public.billing_orders',
    'public.billing_admins', 'public.billing_audit'
  ] loop
    if to_regclass(target_name) is null then
      insert into reset_counts values (target_name, null, 'not installed');
    else
      execute format('select count(*) from %s', to_regclass(target_name)) into row_count;
      insert into reset_counts values (target_name, row_count, 'present');
    end if;
  end loop;
end;
$$;
select * from reset_counts order by table_name;
drop table reset_counts;
