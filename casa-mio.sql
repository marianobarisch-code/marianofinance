-- =====================================================================
-- Finance Mariano — Casa / Mío (Parte 1)
-- Agrega a `expenses` dos columnas:
--   scope : 'casa' | 'mio'      → para quién fue el gasto
--   payer : 'mariano' | 'maria' → quién lo cargó/pagó (las líneas de María, Parte 2)
-- Backfill de todo lo existente según la categoría, y un trigger que pone
-- el valor por defecto en cualquier inserción futura (app, atajo, SQL).
-- Re-ejecutable.
-- =====================================================================
alter table public.expenses add column if not exists scope text check (scope in ('casa','mio'));
alter table public.expenses add column if not exists payer text check (payer in ('mariano','maria'));

-- Regla de defaults (misma que la app): estas categorías son Casa, el resto Mío.
-- Los extraordinarios quedan fuera (scope null): siguen en el pozo anual.
create or replace function public.expenses_default_scope() returns trigger language plpgsql as $$
begin
  if new.scope is null and coalesce(new.is_extraordinary,false)=false then
    new.scope := case when new.category in ('Supermercados','Hogar','Mascotas','Planes Maria','Delivery') then 'casa' else 'mio' end;
  end if;
  if new.payer is null then new.payer := 'mariano'; end if;
  return new;
end $$;
drop trigger if exists trg_expenses_default_scope on public.expenses;
create trigger trg_expenses_default_scope before insert on public.expenses
  for each row execute function public.expenses_default_scope();

-- Backfill de lo ya cargado (solo filas sin marca)
update public.expenses
   set scope = case when category in ('Supermercados','Hogar','Mascotas','Planes Maria','Delivery') then 'casa' else 'mio' end
 where scope is null and coalesce(is_extraordinary,false)=false;
update public.expenses set payer='mariano' where payer is null;

-- Control: cuántas filas quedaron de cada tipo
select coalesce(scope,'(extraordinario)') as scope, payer, count(*) as filas, round(sum(amount)) as ars
  from public.expenses group by 1,2 order by 1,2;
