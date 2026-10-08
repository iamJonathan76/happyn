-- Outils d'assertion des tests de regles d'acces.
--
-- Chaque verification s'execute dans une sous-transaction ANNULEE : un test
-- qui ecrit (pour prouver qu'il a pu ecrire) ne laisse aucune trace, et le
-- test suivant voit les donnees de depart. L'ordre des tests n'a donc aucune
-- importance.
--
-- Les fonctions ne sont pas SECURITY DEFINER : elles s'executent avec le role
-- courant — `anon`, `authenticated` ou `service_role` — exactement comme une
-- requete arrivant par l'API.

create schema if not exists t;

create table t.results (
  n      serial primary key,
  ok     boolean not null,
  label  text not null,
  detail text
);

-- Se presenter comme un visiteur, un compte, ou le serveur.
create function t.as_user(p_id uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated')::text, false);
  set role authenticated;
end $$;

create function t.as_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', false);
  set role anon;
end $$;

create function t.as_server() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', false);
  set role service_role;
end $$;

create function t.record(p_ok boolean, p_label text, p_detail text default null)
returns void language sql as $$
  insert into t.results (ok, label, detail) values (p_ok, p_label, p_detail);
$$;

-- Nombre de lignes visibles ; -1 si l'acces est refuse d'emblee.
create function t.visible(p_sql text) returns integer language plpgsql as $$
declare n integer;
begin
  execute format('select count(*) from (%s) x', p_sql) into n;
  return n;
exception when insufficient_privilege then
  return -1;
end $$;

-- « Ne voit rien » : aucune ligne, ou acces refuse.
create function t.sees_nothing(p_sql text, p_label text) returns void
language plpgsql as $$
declare n integer := t.visible(p_sql);
begin
  perform t.record(n <= 0, p_label, format('%s ligne(s) visible(s)', n));
end $$;

create function t.sees(p_sql text, p_expected integer, p_label text) returns void
language plpgsql as $$
declare n integer := t.visible(p_sql);
begin
  perform t.record(n = p_expected, p_label,
    format('%s ligne(s), %s attendue(s)', n, p_expected));
end $$;

-- Execute une ecriture, mesure, puis annule quoi qu'il arrive.
-- Renvoie le nombre de lignes touchees, ou -1 si l'ecriture a ete refusee.
create function t.try_write(p_sql text, out affected integer, out err text)
language plpgsql as $$
begin
  begin
    execute p_sql;
    get diagnostics affected = row_count;
    raise exception using errcode = 'T0001', message = affected::text;
  exception
    when sqlstate 'T0001' then affected := sqlerrm::integer; err := null;
    when others then affected := -1; err := sqlerrm;
  end;
end $$;

-- « Ne peut pas ecrire » : refuse, ou zero ligne touchee (la RLS filtre
-- silencieusement un UPDATE ou un DELETE qu'elle n'autorise pas).
create function t.cannot_write(p_sql text, p_label text) returns void
language plpgsql as $$
declare r record;
begin
  select * into r from t.try_write(p_sql);
  perform t.record(r.affected <= 0, p_label,
    coalesce('refuse : ' || r.err, format('%s ligne(s) touchee(s)', r.affected)));
end $$;

create function t.can_write(p_sql text, p_label text) returns void
language plpgsql as $$
declare r record;
begin
  select * into r from t.try_write(p_sql);
  perform t.record(r.affected > 0, p_label,
    coalesce('refuse : ' || r.err, format('%s ligne(s) touchee(s)', r.affected)));
end $$;

-- Doit echouer avec un message contenant p_pattern.
create function t.fails_with(p_sql text, p_pattern text, p_label text) returns void
language plpgsql as $$
declare r record;
begin
  select * into r from t.try_write(p_sql);
  perform t.record(
    r.err is not null and r.err ilike '%' || p_pattern || '%',
    p_label,
    coalesce('erreur : ' || r.err, 'AUCUNE ERREUR — l''operation est passee'));
end $$;

grant usage on schema t to anon, authenticated, service_role;
grant execute on all functions in schema t to anon, authenticated, service_role;
grant insert, select on t.results to anon, authenticated, service_role;
grant usage on all sequences in schema t to anon, authenticated, service_role;
