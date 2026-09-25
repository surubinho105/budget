create table if not exists public.daily_tracker (
    user_id uuid not null references auth.users(id) on delete cascade,
    day_date date not null,
    hours_worked numeric(8,2) not null default 0,
    phones_repaired integer not null default 0,
    insurance_signups integer not null default 0,
    total_customers integer not null default 0,
    five_star_reviews integer not null default 0,
    hourly_pay numeric(10,2) not null default 0,
    commission_pay numeric(10,2) not null default 0,
    total_pay numeric(10,2) not null default 0,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint daily_tracker_non_negative check (
        hours_worked >= 0
        and phones_repaired >= 0
        and insurance_signups >= 0
        and total_customers >= 0
        and five_star_reviews >= 0
    ),
    constraint daily_tracker_reviews_lte_customers check (
        five_star_reviews <= total_customers
    ),
    constraint daily_tracker_pk primary key (user_id, day_date)
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists trg_daily_tracker_updated_at on public.daily_tracker;
create trigger trg_daily_tracker_updated_at
before update on public.daily_tracker
for each row
execute procedure public.set_updated_at();

alter table public.daily_tracker enable row level security;

drop policy if exists "daily_tracker_select_own" on public.daily_tracker;
create policy "daily_tracker_select_own"
on public.daily_tracker
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "daily_tracker_insert_own" on public.daily_tracker;
create policy "daily_tracker_insert_own"
on public.daily_tracker
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "daily_tracker_update_own" on public.daily_tracker;
create policy "daily_tracker_update_own"
on public.daily_tracker
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "daily_tracker_delete_own" on public.daily_tracker;
create policy "daily_tracker_delete_own"
on public.daily_tracker
for delete
to authenticated
using (auth.uid() = user_id);

-- If you ran an older insecure version, remove old wide-open policies:
drop policy if exists "daily_tracker_select_all" on public.daily_tracker;
drop policy if exists "daily_tracker_insert_all" on public.daily_tracker;
drop policy if exists "daily_tracker_update_all" on public.daily_tracker;
