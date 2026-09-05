-- =====================================================================
-- Finance Mariano — Atajo de iPhone para cargar gastos ("puerta de servicio")
-- Qué hace: crea una función que inserta un gasto en `expenses` SOLO si
-- viene acompañado de una clave secreta que vive únicamente en tu teléfono.
--   · Categoría automática: la más usada para ese mismo nombre en tu historial.
--     Si el nombre es nuevo, devuelve la lista de categorías para que el atajo pregunte.
--   · Tipo de cambio: dólar blue en vivo (dolarapi, igual que la app); si falla,
--     el último TC que usó la app. USD calculado y TC congelado, como siempre.
--   · Fecha: hoy en hora Argentina.
-- Re-ejecutable. Al final te muestra TU CLAVE (una sola vez): copiala.
-- =====================================================================
create extension if not exists pgcrypto with schema extensions;
create extension if not exists http with schema extensions;

-- Tabla de claves: guarda solo el HASH (ni yo ni nadie que lea la base ve la clave)
create table if not exists public.quick_add_keys(
  id uuid primary key default gen_random_uuid(),
  key_hash text not null unique,
  label text,
  created_at timestamptz default now(),
  last_used_at timestamptz
);
alter table public.quick_add_keys enable row level security;   -- sin policies: invisible desde afuera

-- Genera una clave nueva, guarda su hash y devuelve la clave en claro (solo en este resultado)
create or replace function public.create_quick_key(p_label text default 'iPhone')
returns text language plpgsql security definer set search_path=public,extensions as $$
declare k text;
begin
  k:=encode(gen_random_bytes(16),'hex');
  insert into quick_add_keys(key_hash,label) values(encode(digest(k,'sha256'),'hex'),p_label);
  return k;
end $$;
revoke all on function public.create_quick_key(text) from public, anon, authenticated;

-- La puerta de servicio
create or replace function public.quick_add_expense(p_key text, p_name text, p_amount text, p_category text default null)
returns json language plpgsql security definer set search_path=public,extensions as $$
declare
  v_hash text; v_name text; v_txt text; v_amt numeric; v_cat text; v_cats text[];
  v_fx numeric; v_usd numeric; v_date date; v_fmt text;
begin
  -- 1) clave
  v_hash:=encode(digest(coalesce(p_key,''),'sha256'),'hex');
  if not exists (select 1 from quick_add_keys where key_hash=v_hash) then
    return json_build_object('status','error','message','Clave inválida. Revisá el bloque "Texto" del atajo.');
  end if;
  update quick_add_keys set last_used_at=now() where key_hash=v_hash;

  -- 2) nombre y monto
  v_name:=nullif(btrim(p_name),'');
  if v_name is null then return json_build_object('status','error','message','Falta el nombre del gasto.'); end if;
  v_txt:=regexp_replace(coalesce(p_amount,''),'[^0-9.,]','','g');
  if v_txt ~ '^\d{1,3}(\.\d{3})+(,\d+)?$' then v_txt:=replace(replace(v_txt,'.',''),',','.');  -- 4.500 / 4.500,50
  elsif v_txt ~ '^\d+,\d+$' then v_txt:=replace(v_txt,',','.');                              -- 4500,50
  else v_txt:=replace(v_txt,',','');                                                          -- 4500 / 4500.5
  end if;
  begin v_amt:=v_txt::numeric; exception when others then v_amt:=null; end;
  if v_amt is null or v_amt<=0 then return json_build_object('status','error','message','Monto inválido: '||coalesce(p_amount,'')); end if;

  -- 3) categoría: la que vino, o la más usada para ese nombre en tu historial
  v_cat:=nullif(btrim(p_category),'');
  if v_cat is null then
    select category into v_cat from expenses
    where lower(btrim(name))=lower(v_name) and category<>'Extraordinary'
    group by category order by count(*) desc, max(date) desc limit 1;
  end if;
  if v_cat is null then
    select array_agg(c order by n desc, c) into v_cats from (
      select c,(select count(*) from expenses e where e.category=c) as n
      from unnest(array['Planes Amigos','Uber/Taxis','Planes Maria','Salud','Comidas','Café','Delivery','Estética',
                        'Actividad Física','Auto','Supermercados','Hogar','Planes Familia','Otros','Ropa','Suplementos','Eventos','Mascotas']) as c
    ) s;
    return json_build_object('status','need_category','categories',to_json(v_cats),'message','¿Categoría para '||v_name||'?');
  end if;

  -- 4) tipo de cambio: blue en vivo; si falla, el último de la app
  begin
    select round(((j->>'compra')::numeric+(j->>'venta')::numeric)/2,2) into v_fx
    from (select content::json as j from http_get('https://dolarapi.com/v1/dolares/blue')) t;
  exception when others then v_fx:=null; end;
  if v_fx is null or v_fx<=0 then
    select ars_per_usd into v_fx from expenses where ars_per_usd>0 order by date desc, created_at desc limit 1;
  end if;
  v_fx:=coalesce(v_fx,1400);
  v_usd:=round(v_amt/v_fx,2);
  v_date:=(now() at time zone 'America/Argentina/Buenos_Aires')::date;

  -- 5) insertar con el mismo formato que la app
  insert into expenses(date,name,amount,category,ars_per_usd,amount_usd,subcategory,is_extraordinary,currency)
  values(v_date,v_name,round(v_amt,2),v_cat,v_fx,v_usd,null,false,'ARS');

  v_fmt:=replace(to_char(round(v_amt),'FM999,999,999'),',','.');
  return json_build_object('status','ok','message','✓ '||v_name||' · ARS '||v_fmt||' · '||v_cat,
                           'name',v_name,'amount',v_amt,'category',v_cat,'amount_usd',v_usd,'ars_per_usd',v_fx,'date',v_date);
end $$;
revoke all on function public.quick_add_expense(text,text,text,text) from public;
grant execute on function public.quick_add_expense(text,text,text,text) to anon, authenticated;

-- ⬇️ TU CLAVE: aparece en el resultado de abajo. Copiala ahora.
--    (Si la perdés, corré solo esta última línea otra vez: genera una nueva.)
select public.create_quick_key('iPhone') as "TU CLAVE — copiala ahora";
