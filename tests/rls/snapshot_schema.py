#!/usr/bin/env python3
"""Reconstruit le schema de PRODUCTION (structure seule, aucune donnee).

Pourquoi pas les migrations : `events`, `tickets`, `ticket_types` et `profiles`
ont ete crees dans le tableau de bord Supabase, avant toute migration. Rejouer
le dossier supabase/migrations sur une base vide echoue des la premiere.
Pourquoi pas `supabase db dump` : il exige Docker.

On lit donc le catalogue de la base reelle, en lecture seule, via
`npx supabase db query --linked`, et on ecrit un SQL rejouable sur un Postgres
nu. Le resultat decrit ce qui TOURNE, pas ce que le depot pense qui tourne :
c'est contre lui que les tests des regles d'acces doivent s'executer.

Usage : python3 tests/rls/snapshot_schema.py > tests/rls/schema.sql
"""
import json
import subprocess
import sys

SCHEMAS = ("public", "private")


def q(sql):
    out = subprocess.run(
        ["npx", "supabase", "db", "query", "--linked", sql],
        capture_output=True, text=True, check=False,
    ).stdout
    start = out.find("{")
    if start < 0:
        sys.exit(f"requete sans reponse JSON :\n{sql}\n{out[-500:]}")
    data = json.loads(out[start:])
    if "rows" not in data:
        sys.exit(f"echec de la requete :\n{sql}\n{data}")
    return data["rows"]


def ident(name):
    return '"' + name.replace('"', '""') + '"'


IN = "(" + ",".join(f"'{s}'" for s in SCHEMAS) + ")"
out = []
w = out.append

w("-- GENERE par tests/rls/snapshot_schema.py — ne pas editer a la main.")
w("-- Structure de la base de production, sans aucune donnee.")
w("set check_function_bodies = off;")
w("set client_min_messages = warning;")
w(open(__file__.replace("snapshot_schema.py", "supabase_shim.sql")).read())

# ── Schemas ────────────────────────────────────────────────────────────────
for s in SCHEMAS:
    if s != "public":
        w(f"create schema if not exists {s};")

# ── Sequences ──────────────────────────────────────────────────────────────
for r in q(f"""select n.nspname s, c.relname n from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where c.relkind='S' and n.nspname in {IN}"""):
    w(f"create sequence if not exists {r['s']}.{ident(r['n'])};")

# ── Tables : colonnes ──────────────────────────────────────────────────────
cols = q(f"""select n.nspname s, c.relname t, a.attname col,
    format_type(a.atttypid, a.atttypmod) typ, a.attnotnull nn,
    pg_get_expr(d.adbin, d.adrelid) def, a.attgenerated gen, a.attidentity idn
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  join pg_attribute a on a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
  left join pg_attrdef d on d.adrelid=c.oid and d.adnum=a.attnum
  where c.relkind in ('r','p') and n.nspname in {IN}
  order by n.nspname, c.relname, a.attnum""")
tables = {}
defaults = []  # poses APRES les fonctions : un defaut peut en appeler une
for r in cols:
    tables.setdefault((r["s"], r["t"]), []).append(r)
for (s, t), cs in tables.items():
    lines = []
    for c in cs:
        line = f"  {ident(c['col'])} {c['typ']}"
        if c["gen"] == "s":
            line += f" generated always as ({c['def']}) stored"
        elif c["idn"] in ("a", "d"):
            line += " generated " + ("always" if c["idn"] == "a" else "by default") + " as identity"
        elif c["def"] is not None:
            defaults.append(
                f"alter table {s}.{ident(t)} alter column {ident(c['col'])} set default {c['def']};")
        if c["nn"]:
            line += " not null"
        lines.append(line)
    w(f"create table {s}.{ident(t)} (\n" + ",\n".join(lines) + "\n);")

# ── Fonctions (corps non verifies a la creation : check_function_bodies) ───
for r in q(f"""select pg_get_functiondef(p.oid) d from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in {IN} and p.prokind in ('f','p')
    and not exists (select 1 from pg_depend dp where dp.objid=p.oid and dp.deptype='e')
  order by p.proname"""):
    w(r["d"].rstrip() + ";")

for d in defaults:
    w(d)

# ── Contraintes : cles et verifications d'abord, cles etrangeres ensuite ──
cons = q(f"""select n.nspname s, c.relname t, k.conname, k.contype,
    pg_get_constraintdef(k.oid) def
  from pg_constraint k join pg_class c on c.oid=k.conrelid
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in {IN} and k.contype in ('p','u','c','f','x')
  order by case k.contype when 'p' then 0 when 'u' then 1 when 'x' then 2 when 'c' then 3 else 4 end""")
for r in cons:
    w(f"alter table {r['s']}.{ident(r['t'])} add constraint {ident(r['conname'])} {r['def']};")

# ── Vues, dans l'ordre de leurs dependances ────────────────────────────────
views = q(f"""select n.nspname s, c.relname v, pg_get_viewdef(c.oid) def,
    coalesce(array_to_string(c.reloptions, ','), '') opts
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where c.relkind='v' and n.nspname in {IN}""")
for r in views:
    opts = f" with ({r['opts']})" if r["opts"] else ""
    w(f"create or replace view {r['s']}.{ident(r['v'])}{opts} as {r['def'].rstrip().rstrip(';')};")

# ── Index qui ne portent pas une contrainte ────────────────────────────────
for r in q(f"""select pg_get_indexdef(i.indexrelid) d from pg_index i
  join pg_class c on c.oid=i.indrelid join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in {IN}
    and not exists (select 1 from pg_constraint k where k.conindid=i.indexrelid)"""):
    w(r["d"] + ";")

# ── Declencheurs, y compris ceux de public poses sur auth.users ────────────
for r in q(f"""select pg_get_triggerdef(tg.oid) d from pg_trigger tg
  join pg_class c on c.oid=tg.tgrelid join pg_namespace n on n.oid=c.relnamespace
  join pg_proc p on p.oid=tg.tgfoid join pg_namespace pn on pn.oid=p.pronamespace
  where not tg.tgisinternal
    and (n.nspname in {IN} or (n.nspname='auth' and pn.nspname='public'))"""):
    w(r["d"] + ";")

# ── RLS et politiques ──────────────────────────────────────────────────────
for r in q(f"""select n.nspname s, c.relname t, c.relrowsecurity rls, c.relforcerowsecurity f
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where c.relkind in ('r','p') and n.nspname in {IN}"""):
    if r["rls"]:
        w(f"alter table {r['s']}.{ident(r['t'])} enable row level security;")
    if r["f"]:
        w(f"alter table {r['s']}.{ident(r['t'])} force row level security;")
CMD = {"r": "select", "a": "insert", "w": "update", "d": "delete", "*": "all"}
for r in q(f"""select n.nspname s, c.relname t, p.polname, p.polpermissive perm, p.polcmd cmd,
    coalesce((select string_agg(case when x=0 then 'public' else quote_ident(rolname) end, ', ')
       from unnest(p.polroles) x left join pg_roles ro on ro.oid=x), 'public') roles,
    pg_get_expr(p.polqual, p.polrelid) qual, pg_get_expr(p.polwithcheck, p.polrelid) chk
  from pg_policy p join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in {IN}"""):
    stmt = (f"create policy {ident(r['polname'])} on {r['s']}.{ident(r['t'])} as "
            f"{'permissive' if r['perm'] else 'restrictive'} for {CMD[r['cmd']]} to {r['roles']}")
    if r["qual"]:
        stmt += f" using ({r['qual']})"
    if r["chk"]:
        stmt += f" with check ({r['chk']})"
    w(stmt + ";")

# ── Droits : tables et vues ────────────────────────────────────────────────
w("-- Droits : on part de zero, puis on rejoue exactement ceux de la production.")
for (s, t) in list(tables.keys()) + [(v["s"], v["v"]) for v in views]:
    w(f"revoke all on {s}.{ident(t)} from public, anon, authenticated, service_role;")
for r in q(f"""select table_schema s, table_name t, grantee g,
    string_agg(privilege_type, ', ') privs
  from information_schema.role_table_grants
  where table_schema in {IN} and grantee in ('anon','authenticated','service_role')
  group by 1,2,3"""):
    w(f"grant {r['privs']} on {r['s']}.{ident(r['t'])} to {r['g']};")

# ── Droits : fonctions ─────────────────────────────────────────────────────
for r in q(f"""select p.oid::regprocedure::text sig,
    has_function_privilege('anon', p.oid, 'execute') a,
    has_function_privilege('authenticated', p.oid, 'execute') au,
    has_function_privilege('service_role', p.oid, 'execute') sr
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in {IN} and p.prokind in ('f','p')
    and not exists (select 1 from pg_depend dp where dp.objid=p.oid and dp.deptype='e')"""):
    w(f"revoke all on function {r['sig']} from public, anon, authenticated, service_role;")
    for role, ok in (("anon", r["a"]), ("authenticated", r["au"]), ("service_role", r["sr"])):
        if ok:
            w(f"grant execute on function {r['sig']} to {role};")

w("grant usage on schema public to anon, authenticated, service_role;")
print("\n\n".join(out))
