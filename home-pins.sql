-- Pines del Home: recordatorios sueltos ("no quiero que se me pase") que aparecen
-- en la card del mes en curso hasta que Mariano los marca como listos.
create table if not exists public.home_pins (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  note text,
  month text not null,            -- 'YYYY-MM' del mes en que nació; se arrastra a los siguientes si sigue abierto
  created_at timestamptz not null default now(),
  done_at timestamptz
);
alter table public.home_pins enable row level security;
drop policy if exists fin_authed_all on public.home_pins;
create policy fin_authed_all on public.home_pins for all to authenticated using (true) with check (true);
grant select, insert, update, delete on public.home_pins to authenticated;

insert into public.home_pins (title, note, month)
select 'Europcar', 'Consumo en la tarjeta BBVA que estoy reclamando · sin novedades todavía', '2026-09'
where not exists (select 1 from public.home_pins where title='Europcar' and done_at is null);

select id, title, note, month, done_at from public.home_pins;
