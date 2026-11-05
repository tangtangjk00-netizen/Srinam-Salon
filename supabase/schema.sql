-- Run once in Supabase SQL Editor. All timestamps use timestamptz, client shows Asia/Bangkok.
create extension if not exists pgcrypto;
create table if not exists public.admins (
 user_id uuid primary key references auth.users(id) on delete cascade
);
create table if not exists public.services (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(name) between 1 and 100),
 price numeric(10,2) check(price is null or price >= 0),
 duration_minutes integer not null default 60 check(duration_minutes between 30 and 240 and duration_minutes % 30 = 0),
 active boolean not null default true,
 sort_order integer not null default 0
);
create table if not exists public.bookings (
 id uuid primary key default gen_random_uuid(),
 customer_name text not null check(length(customer_name) between 2 and 100),
 customer_phone text not null check(customer_phone ~ '^0[0-9]{9}$'),
 service_id uuid not null references public.services(id),
 starts_at timestamptz not null,
 ends_at timestamptz not null,
 status text not null default 'pending' check(status in ('pending','confirmed','cancelled')),
 created_at timestamptz not null default now(),
 constraint valid_interval check(ends_at > starts_at)
);
create index if not exists bookings_start_idx on public.bookings(starts_at);
create index if not exists bookings_status_idx on public.bookings(status);
-- Prevent overlapping active bookings even under simultaneous requests.
create extension if not exists btree_gist;
alter table public.bookings drop constraint if exists bookings_no_overlap;
alter table public.bookings add constraint bookings_no_overlap exclude using gist
 (tstzrange(starts_at,ends_at,'[)') with &&) where (status in ('pending','confirmed'));

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.admins where user_id = (select auth.uid()));
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon,authenticated;

alter table public.admins enable row level security;
alter table public.services enable row level security;
alter table public.bookings enable row level security;

-- Only authenticated admin can read all bookings and update status.
drop policy if exists admin_read_bookings on public.bookings;
create policy admin_read_bookings on public.bookings for select to authenticated using
 ((select public.is_admin()));
drop policy if exists admin_update_bookings on public.bookings;
create policy admin_update_bookings on public.bookings for update to authenticated using
 ((select public.is_admin())) with check
 ((select public.is_admin()));
drop policy if exists public_read_services on public.services;
create policy public_read_services on public.services for select to anon, authenticated using (active = true or (select public.is_admin()));
drop policy if exists admin_write_services on public.services;
create policy admin_write_services on public.services for all to authenticated using
 ((select public.is_admin())) with check
 ((select public.is_admin()));
-- No direct public INSERT/SELECT/UPDATE on bookings. Use controlled functions.
revoke all on public.admins from anon, authenticated;
revoke all on public.bookings from anon, authenticated;
grant select, update(status) on public.bookings to authenticated;
grant select on public.services to anon, authenticated;
grant insert, update on public.services to authenticated;

create or replace function public.available_slots(p_day date,p_service_id uuid)
returns table(slot_time text) language plpgsql security definer set search_path = '' as $$
declare v_day_start timestamptz; v_slot timestamptz; v_duration integer;
begin
 if p_day < (now() at time zone 'Asia/Bangkok')::date or p_day > ((now() at time zone 'Asia/Bangkok')::date + 60) then return; end if;
 if extract(isodow from p_day) = 7 then return; end if;
 select duration_minutes into v_duration from public.services where id=p_service_id and active=true;
 if v_duration is null then return; end if;
 v_day_start := (p_day::text || ' 09:00:00 Asia/Bangkok')::timestamptz;
 for v_slot in select generate_series(v_day_start, v_day_start + interval '10 hours' - make_interval(mins=>v_duration), interval '30 minutes') loop
  if v_slot > now() and not exists(select 1 from public.bookings b where b.status in ('pending','confirmed') and b.starts_at < v_slot + make_interval(mins=>v_duration) and b.ends_at > v_slot) then
   slot_time := to_char(v_slot at time zone 'Asia/Bangkok','HH24:MI'); return next;
  end if;
 end loop;
end $$;

create or replace function public.create_booking(p_name text,p_phone text,p_service_id uuid,p_day date,p_time text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_start timestamptz;v_end timestamptz;v_duration integer;v_id uuid;
begin
 if length(trim(p_name)) not between 2 and 100 or p_phone !~ '^0[0-9]{9}$' then raise exception 'กรุณาตรวจสอบชื่อและเบอร์โทร'; end if;
 if p_day < (now() at time zone 'Asia/Bangkok')::date or p_day > ((now() at time zone 'Asia/Bangkok')::date + 60) or extract(isodow from p_day)=7 then raise exception 'วันที่ไม่เปิดรับจอง'; end if;
 if p_time !~ '^(09|1[0-8]):(00|30)$' or p_time='18:30' then raise exception 'เวลานอกเวลาทำการ'; end if;
 select duration_minutes into v_duration from public.services where id=p_service_id and active=true;
 if v_duration is null then raise exception 'ไม่พบบริการ'; end if;
 v_start := (p_day::text || ' ' || p_time || ':00 Asia/Bangkok')::timestamptz;
 v_end := v_start + make_interval(mins=>v_duration);
 if v_start <= now() or (v_end at time zone 'Asia/Bangkok')::date <> p_day or (v_end at time zone 'Asia/Bangkok')::time > time '19:00' then raise exception 'เวลานอกเวลาทำการ'; end if;
 insert into public.bookings(customer_name,customer_phone,service_id,starts_at,ends_at)
 values(trim(p_name),p_phone,p_service_id,v_start,v_end) returning id into v_id;
 return v_id;
exception when exclusion_violation then raise exception 'เวลานี้มีการจองแล้ว กรุณาเลือกเวลาอื่น';
end $$;

revoke all on function public.available_slots(date,uuid) from public;
revoke all on function public.create_booking(text,text,uuid,date,text) from public;
grant execute on function public.available_slots(date,uuid) to anon,authenticated;
grant execute on function public.create_booking(text,text,uuid,date,text) to anon,authenticated;

insert into public.services(name,price,duration_minutes,sort_order)
select v.name,v.price,v.duration,v.ord from (values
 ('สระ ไดร์ หนีบ',79::numeric,60,1),('ตัดผม',null::numeric,60,2),('ดัดผม',null::numeric,120,3),('สปาผม',null::numeric,60,4),('เคลือบเงาผม',null::numeric,90,5)
) as v(name,price,duration,ord)
where not exists (select 1 from public.services);

-- IMPORTANT: After creating your user in Supabase Auth, replace the email and run separately:
-- insert into public.admins(user_id)
-- select id from auth.users where email = 'YOUR_ADMIN_EMAIL@example.com'
-- on conflict do nothing;
