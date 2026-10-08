#!/usr/bin/env bash
# Tests des regles d'acces, contre le schema de production.
#
#   tests/rls/run.sh            utilise tests/rls/schema.sql tel quel
#   tests/rls/run.sh --refresh  le regenere d'abord depuis la production
#                               (lecture seule, via la CLI Supabase liee)
#   tests/rls/run.sh x.sql      applique d'abord une migration pas encore en
#                               production, pour la valider avant de la livrer
#
# Monte un Postgres jetable dans un dossier temporaire, rejoue le schema,
# charge les donnees de test, verifie chaque regle, puis detruit tout. Sort en
# erreur des qu'une regle n'est pas tenue : a lancer avant chaque migration
# qui touche aux droits.
#
# Prerequis : Postgres 17 (`brew install postgresql@17`).

set -euo pipefail
cd "$(dirname "$0")/../.."

PG_BIN="${PG_BIN:-/opt/homebrew/opt/postgresql@17/bin}"
PORT="${RLS_TEST_PORT:-54399}"
export LC_ALL=en_US.UTF-8

PENDING=()
for arg in "$@"; do
  if [[ "$arg" == "--refresh" ]]; then
    echo "Lecture du schema de production…"
    python3 tests/rls/snapshot_schema.py > tests/rls/schema.sql
  else
    PENDING+=("$arg")
  fi
done

DIR="$(mktemp -d)"
cleanup() { "$PG_BIN/pg_ctl" -D "$DIR/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$DIR"; }
trap cleanup EXIT

"$PG_BIN/initdb" -D "$DIR/data" -U postgres -E UTF8 >/dev/null
"$PG_BIN/pg_ctl" -D "$DIR/data" -o "-p $PORT -k '' -c listen_addresses=localhost" -l "$DIR/log" start >/dev/null
until "$PG_BIN/pg_isready" -h localhost -p "$PORT" -q; do sleep 0.2; done

PSQL=("$PG_BIN/psql" -h localhost -p "$PORT" -U postgres -d postgres -q -v ON_ERROR_STOP=1)
"${PSQL[@]}" -f tests/rls/schema.sql >/dev/null
# Les migrations pas encore appliquees en production, passees en argument :
#   tests/rls/run.sh supabase/migrations/2026..._x.sql
for m in ${PENDING[@]+"${PENDING[@]}"}; do "${PSQL[@]}" -f "$m" >/dev/null; done
"${PSQL[@]}" -f tests/rls/helpers.sql >/dev/null
"${PSQL[@]}" -f tests/rls/access_rules.sql >/dev/null

"${PSQL[@]}" -tA -F $'\t' -c "select case when ok then 'ok  ' else 'ECHEC' end, label, case when ok then '' else detail end from t.results order by n" \
  | while IFS=$'\t' read -r status label detail; do
      if [[ "$status" == "ok  " ]]; then echo "  ok     $label"; else echo "  ECHEC  $label  —  $detail"; fi
    done

FAILED="$("${PSQL[@]}" -tA -c "select count(*) from t.results where not ok")"
TOTAL="$("${PSQL[@]}" -tA -c "select count(*) from t.results")"
echo
echo "$((TOTAL - FAILED)) / $TOTAL regles tenues."
[[ "$FAILED" == "0" ]]
