-- Pool-It production schema (Supabase-native)
-- Run this once in the Supabase SQL Editor of the production project (beiovshyiawmgprqnhrw).

-- ---------------------------------------------------------------------------
-- Cleanup: drop the legacy (Prisma-era) tables that conflict with this schema.
-- Guarded by legacy-only columns so this is safe to re-run (it will NOT drop
-- the new tables once they exist). They are expected to be EMPTY.
-- ---------------------------------------------------------------------------
do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'bookings' and column_name = 'seats_booked') then
    drop table public.bookings cascade;
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'rides' and column_name = 'total_seats') then
    drop table public.rides cascade;
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'vehicles' and column_name = 'user_id') then
    drop table public.vehicles cascade;
  end if;
end $$;
-- These are not part of the new schema, so dropping them is always safe
drop table if exists public.users cascade;
drop table if exists public.legacy_profiles cascade;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
do $$ begin create type ride_status as enum ('draft', 'published', 'in_progress', 'completed', 'cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type booking_status as enum ('pending', 'confirmed', 'rejected', 'cancelled', 'completed'); exception when duplicate_object then null; end $$;
do $$ begin create type pet_policy as enum ('not_allowed', 'allowed', 'small_pets_only', 'allowed_with_conditions'); exception when duplicate_object then null; end $$;
do $$ begin create type vehicle_verification_status as enum ('pending', 'verified', 'rejected'); exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  full_name  text not null default '',
  phone      text,
  avatar_url text,
  is_admin   boolean not null default false,
  is_driver  boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.otp_requests (
  phone        text primary key,
  code_hash    text not null,
  expires_at   timestamptz not null,
  attempts     integer not null default 0,
  last_sent_at timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.vehicles (
  id                  uuid primary key default gen_random_uuid(),
  driver_id           uuid not null references public.profiles (id) on delete cascade,
  make                text not null default '',
  model               text not null default '',
  year                text not null default '',
  color               text not null default '',
  registration_number text not null unique,
  seats               integer not null default 4 check (seats > 0),
  verification_status vehicle_verification_status not null default 'pending',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create table if not exists public.rides (
  id              uuid primary key default gen_random_uuid(),
  driver_id       uuid not null references public.profiles (id) on delete cascade,
  vehicle_id      uuid references public.vehicles (id) on delete set null,
  driver_name     text not null default '',
  source_name     text not null,
  source_lat      double precision,
  source_lng      double precision,
  destination_name text not null,
  destination_lat double precision,
  destination_lng double precision,
  departure_at    timestamptz not null,
  available_seats integer not null check (available_seats >= 0),
  initial_seats   integer not null check (initial_seats > 0),
  pet_policy      pet_policy not null default 'not_allowed',
  status          ride_status not null default 'published',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (available_seats <= initial_seats)
);

create table if not exists public.bookings (
  id              uuid primary key default gen_random_uuid(),
  ride_id         uuid not null references public.rides (id) on delete cascade,
  passenger_id    uuid not null references public.profiles (id) on delete cascade,
  passenger_name  text not null default '',
  seats_requested integer not null check (seats_requested > 0),
  pickup_name     text not null default '',
  pickup_lat      double precision,
  pickup_lng      double precision,
  dropoff_name    text not null default '',
  dropoff_lat     double precision,
  dropoff_lng     double precision,
  status          booking_status not null default 'pending',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table if not exists public.chat_messages (
  id                uuid primary key default gen_random_uuid(),
  ride_id           uuid not null references public.rides (id) on delete cascade,
  sender_id         uuid not null references public.profiles (id) on delete cascade,
  client_message_id uuid not null,
  sender_name       text not null default '',
  body              text not null check (char_length(body) between 1 and 4000),
  created_at        timestamptz not null default now()
);

create table if not exists public.app_config (
  id         integer primary key default 1 check (id = 1),
  quiz_url   text not null default '',
  updated_by uuid references public.profiles (id),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
create unique index if not exists bookings_active_unique on public.bookings (ride_id, passenger_id)
  where status in ('pending', 'confirmed');
create index if not exists bookings_ride_idx on public.bookings (ride_id);
create index if not exists bookings_passenger_idx on public.bookings (passenger_id, created_at desc);

create unique index if not exists chat_messages_sender_id_client_message_id_key
  on public.chat_messages (sender_id, client_message_id);
create index if not exists chat_ride_time_idx on public.chat_messages (ride_id, created_at desc);
create index if not exists chat_dedup_idx on public.chat_messages (sender_id, client_message_id);

create index if not exists rides_published_search on public.rides (status, departure_at)
  where status = 'published';
create index if not exists rides_driver_idx on public.rides (driver_id, departure_at desc);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace trigger profiles_updated_at     before update on public.profiles     for each row execute function set_updated_at();
create or replace trigger otp_requests_updated_at before update on public.otp_requests for each row execute function set_updated_at();
create or replace trigger vehicles_updated_at     before update on public.vehicles     for each row execute function set_updated_at();
create or replace trigger rides_updated_at        before update on public.rides        for each row execute function set_updated_at();
create or replace trigger bookings_updated_at     before update on public.bookings     for each row execute function set_updated_at();
create or replace trigger app_config_updated_at   before update on public.app_config   for each row execute function set_updated_at();

create or replace function public.protect_privileged_fields()
returns trigger language plpgsql
as $$
begin
  if auth.uid() is not null then
    if new.is_admin is distinct from old.is_admin then
      raise exception 'Only admins can change is_admin';
    end if;
    if tg_table_name = 'vehicles' and new.verification_status is distinct from old.verification_status then
      raise exception 'Only admins can change verification_status';
    end if;
  end if;
  return new;
end;
$$;

create or replace trigger profiles_protect before update on public.profiles for each row execute function protect_privileged_fields();
create or replace trigger vehicles_protect before update on public.vehicles for each row execute function protect_privileged_fields();

-- Auto-create a profile row when a new auth user signs up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = 'public'
as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''), new.phone);
  return new;
end;
$$;

create or replace trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

-- Helper used by RLS: checks admin status WITHOUT re-entering RLS on profiles
-- (a self-referential subquery inside a profiles policy causes infinite recursion).
create or replace function public.is_admin(uid uuid)
returns boolean language sql stable security definer set search_path = 'public'
as $$
  select coalesce((select p.is_admin from public.profiles p where p.id = uid), false);
$$;

grant execute on function public.is_admin(uuid) to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- RPC functions
-- ---------------------------------------------------------------------------
create or replace function public.approve_booking(p_booking_id uuid)
returns jsonb language plpgsql security definer set search_path = 'public'
as $function$
declare
  v_booking public.bookings%rowtype;
  v_ride public.rides%rowtype;
  v_available int;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then raise exception 'booking_not_found'; end if;

  select * into v_ride from public.rides where id = v_booking.ride_id for update;
  if not found then raise exception 'ride_not_found'; end if;

  if v_ride.driver_id <> auth.uid() then raise exception 'only_driver_can_approve'; end if;
  if v_booking.status <> 'pending' then raise exception 'booking_not_pending'; end if;
  if v_ride.status <> 'published' then raise exception 'ride_not_available'; end if;
  if v_booking.seats_requested > v_ride.available_seats then raise exception 'insufficient_seats'; end if;

  update public.rides
     set available_seats = v_ride.available_seats - v_booking.seats_requested,
         updated_at = now()
   where id = v_ride.id
   returning available_seats into v_available;

  update public.bookings
     set status = 'confirmed', updated_at = now()
   where id = p_booking_id
   returning * into v_booking;

  return jsonb_build_object(
    'booking_id', v_booking.id,
    'status', v_booking.status,
    'seats_requested', v_booking.seats_requested,
    'available_seats', v_available
  );
end;
$function$;

create or replace function public.reject_booking(p_booking_id uuid)
returns jsonb language plpgsql security definer set search_path = 'public'
as $function$
declare
  v_booking public.bookings%rowtype;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  select * into v_booking from public.bookings where id = p_booking_id;
  if not found then raise exception 'booking_not_found'; end if;

  if not exists (select 1 from public.rides r where r.id = v_booking.ride_id and r.driver_id = auth.uid()) then
    raise exception 'only_driver_can_reject';
  end if;
  if v_booking.status <> 'pending' then raise exception 'booking_not_pending'; end if;

  update public.bookings set status = 'rejected', updated_at = now()
   where id = p_booking_id
   returning * into v_booking;

  return jsonb_build_object('booking_id', v_booking.id, 'status', v_booking.status);
end;
$function$;

create or replace function public.cancel_booking(p_booking_id uuid)
returns jsonb language plpgsql security definer set search_path = 'public'
as $function$
declare
  v_booking public.bookings%rowtype;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  select * into v_booking from public.bookings where id = p_booking_id;
  if not found then raise exception 'booking_not_found'; end if;
  if v_booking.status <> 'pending' and v_booking.status <> 'confirmed' then
    raise exception 'booking_not_active';
  end if;

  if v_booking.passenger_id <> auth.uid()
     and not exists (select 1 from public.rides r where r.id = v_booking.ride_id and r.driver_id = auth.uid()) then
    raise exception 'not_allowed';
  end if;

  if v_booking.status = 'confirmed' then
    update public.rides
       set available_seats = available_seats + v_booking.seats_requested,
           updated_at = now()
     where id = v_booking.ride_id;
  end if;

  update public.bookings set status = 'cancelled', updated_at = now()
   where id = p_booking_id
   returning * into v_booking;

  return jsonb_build_object('booking_id', v_booking.id, 'status', v_booking.status);
end;
$function$;

create or replace function public.update_app_config(p_quiz_url text)
returns jsonb language plpgsql security definer set search_path = 'public'
as $function$
declare
  v_row public.app_config%rowtype;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin) then
    raise exception 'admins_only';
  end if;
  if p_quiz_url is not null and p_quiz_url <> '' and p_quiz_url not similar to 'https?://%' then
    raise exception 'invalid_url';
  end if;

  update public.app_config
     set quiz_url = coalesce(p_quiz_url, ''), updated_by = auth.uid(), updated_at = now()
   where id = 1
   returning * into v_row;

  return jsonb_build_object(
    'id', v_row.id,
    'quiz_url', v_row.quiz_url,
    'updated_by', v_row.updated_by,
    'updated_at', v_row.updated_at
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles     enable row level security;
alter table public.otp_requests enable row level security;
alter table public.vehicles     enable row level security;
alter table public.rides        enable row level security;
alter table public.bookings     enable row level security;
alter table public.chat_messages enable row level security;
alter table public.app_config   enable row level security;

-- Drop any prior policies so this script is safe to re-run
do $$
declare pol record;
begin
  for pol in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('profiles','otp_requests','vehicles','rides','bookings','chat_messages','app_config')
  loop
    execute format('drop policy if exists %I on public.%I', pol.policyname, pol.tablename);
  end loop;
end $$;

create policy "profiles_select" on public.profiles for select to authenticated
  using (auth.uid() = id or public.is_admin(auth.uid()));
create policy "profiles_insert" on public.profiles for insert to authenticated
  with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

-- otp_requests: strictly server-side, no client access
revoke all on public.otp_requests from anon, authenticated;

create policy "vehicles_select" on public.vehicles for select to authenticated using (driver_id = auth.uid());
create policy "vehicles_insert" on public.vehicles for insert to authenticated with check (driver_id = auth.uid());
create policy "vehicles_update" on public.vehicles for update to authenticated using (driver_id = auth.uid()) with check (driver_id = auth.uid());
create policy "vehicles_delete" on public.vehicles for delete to authenticated using (driver_id = auth.uid());

create policy "rides_select" on public.rides for select to authenticated
  using (driver_id = auth.uid() or status = 'published');
create policy "rides_insert" on public.rides for insert to authenticated with check (driver_id = auth.uid());
create policy "rides_update" on public.rides for update to authenticated using (driver_id = auth.uid()) with check (driver_id = auth.uid());
create policy "rides_delete" on public.rides for delete to authenticated using (driver_id = auth.uid());

create policy "bookings_select" on public.bookings for select to authenticated
  using (passenger_id = auth.uid()
         or exists (select 1 from public.rides r where r.id = bookings.ride_id and r.driver_id = auth.uid()));
create policy "bookings_insert" on public.bookings for insert to authenticated
  with check (passenger_id = auth.uid()
              and (select rides.driver_id from public.rides where rides.id = bookings.ride_id) is distinct from auth.uid());
-- updates/deletes go through the RPC functions only
revoke update, delete on public.bookings from anon, authenticated;

create policy "chat_select" on public.chat_messages for select to authenticated
  using (sender_id = auth.uid()
         or exists (select 1 from public.rides r where r.id = chat_messages.ride_id and r.driver_id = auth.uid())
         or exists (select 1 from public.bookings b
                     where b.ride_id = chat_messages.ride_id and b.passenger_id = auth.uid()
                       and b.status in ('pending', 'confirmed', 'completed')));
create policy "chat_insert" on public.chat_messages for insert to authenticated
  with check (sender_id = auth.uid()
              and (exists (select 1 from public.rides r where r.id = chat_messages.ride_id and r.driver_id = auth.uid())
                   or exists (select 1 from public.bookings b
                               where b.ride_id = chat_messages.ride_id and b.passenger_id = auth.uid()
                                 and b.status in ('pending', 'confirmed'))));

create policy "app_config_select" on public.app_config for select using (true);

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;

-- Re-apply restrictions AFTER the grants above (the grant-all would otherwise undo them)
revoke all on public.otp_requests from anon, authenticated;
revoke update, delete on public.bookings from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
do $$ begin
  alter publication supabase_realtime add table public.rides, public.bookings, public.chat_messages;
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- Seed
-- ---------------------------------------------------------------------------
insert into public.app_config (id, quiz_url) values (1, '')
on conflict (id) do nothing;