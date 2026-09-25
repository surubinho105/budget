-- Budget Tracker setup — run once in the new project's Supabase SQL Editor.
-- Matches what homepage.html and budgetcalander.html actually read/write.
-- NOTE: the app has no login, so these policies let anyone holding the
-- publishable key (which is visible in the page source) read and write.

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

-- 1) Daily work log (app upserts on day_date)
create table if not exists public.daily_tracker (
    day_date date primary key,
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
        hours_worked >= 0 and phones_repaired >= 0 and insurance_signups >= 0
        and total_customers >= 0 and five_star_reviews >= 0
    ),
    constraint daily_tracker_reviews_lte_customers check (five_star_reviews <= total_customers)
);

drop trigger if exists trg_daily_tracker_updated_at on public.daily_tracker;
create trigger trg_daily_tracker_updated_at
before update on public.daily_tracker
for each row execute procedure public.set_updated_at();

-- 2) Daily spending (used by homepage + calendar)
create table if not exists public.daily_spending (
    id bigint generated always as identity primary key,
    entry_date date not null,
    description text,
    amount numeric(10,2) not null default 0,
    created_at timestamptz not null default now()
);
create index if not exists daily_spending_entry_date_idx on public.daily_spending (entry_date);

-- 3) Monthly bills
create table if not exists public.expense_items (
    id bigint generated always as identity primary key,
    name text not null,
    amount numeric(10,2) not null default 0,
    is_active boolean not null default true,
    created_at timestamptz not null default now()
);

-- 4) Paid/unpaid status per bill per month (month_key like '2026-09')
create table if not exists public.expense_payments (
    expense_id bigint not null references public.expense_items(id) on delete cascade,
    month_key text not null,
    is_paid boolean not null default false,
    created_at timestamptz not null default now(),
    constraint expense_payments_unique unique (expense_id, month_key)
);

-- Row Level Security: enabled, with open access for the anon (publishable) key
do $$
declare t text;
begin
    foreach t in array array['daily_tracker','daily_spending','expense_items','expense_payments'] loop
        execute format('alter table public.%I enable row level security', t);
        execute format('drop policy if exists %I on public.%I', t || '_open_access', t);
        execute format(
            'create policy %I on public.%I for all to anon, authenticated using (true) with check (true)',
            t || '_open_access', t
        );
    end loop;
end $$;
