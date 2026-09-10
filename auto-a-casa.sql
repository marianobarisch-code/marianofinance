-- 2026-09-10: los variables del auto (nafta, lavado → categoría Auto) pasan a la economía familiar.
-- Seguro y Patente siguen siendo fijos personales de Mariano (FIXED_MIO_ITEMS en la app).
-- Aplica desde septiembre 2026: los meses anteriores ya se liquidaron con María y quedan como estaban.
create or replace function public.expenses_default_scope() returns trigger language plpgsql as $$
begin
  if new.scope is null and coalesce(new.is_extraordinary,false)=false then
    new.scope := case when new.category in ('Supermercados','Hogar','Mascotas','Planes Maria','Delivery','Auto') then 'casa' else 'mio' end;
  end if;
  if new.payer is null then new.payer := 'mariano'; end if;
  return new;
end $$;
update public.expenses set scope='casa' where category='Auto' and date>='2026-09-01' and coalesce(is_extraordinary,false)=false;
select to_char(date,'YYYY-MM') mes, scope, count(*) from expenses where category='Auto' group by 1,2 order by 1;
