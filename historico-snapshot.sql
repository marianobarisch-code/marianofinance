-- =====================================================================
-- Finance Mariano — Histórico de Google Sheets → Supabase (copia literal)
-- Crea la tabla donde la app guarda una copia exacta de las 3 hojas
-- (Variables, Income and Expending, Net Worth). La copia la hace la app
-- desde Home → "Copiar a Supabase y verificar", y compara celda por celda.
-- Google Sheets NO se toca: queda como respaldo.
-- Re-ejecutable.
-- =====================================================================
create table if not exists public.sheet_snapshots(
  range      text primary key,          -- ej. 'Variables!A:D'
  payload    jsonb not null,            -- la hoja tal cual (matriz de filas)
  rows       integer not null default 0,
  cells      integer not null default 0,
  taken_at   timestamptz not null default now()
);
alter table public.sheet_snapshots enable row level security;
drop policy if exists fin_authed_all on public.sheet_snapshots;
create policy fin_authed_all on public.sheet_snapshots for all to authenticated using (true) with check (true);
select 'tabla lista' as resultado;
