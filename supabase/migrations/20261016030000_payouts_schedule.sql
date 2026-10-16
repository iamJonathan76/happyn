-- Les versements aux organisateurs partent tout seuls, une fois par jour.
--
-- `run-payouts` existait, déployée, protégée par PAYOUT_HOOK_SECRET — mais
-- rien ne l'appelait jamais : `pg_cron` n'était pas installé (constaté le
-- 2026-10-07, toujours vrai le 2026-10-16). L'écran « Get paid » annonçait une
-- date de versement que rien ne tenait.
--
-- ── Le secret ───────────────────────────────────────────────────────────────
-- Il vit dans private.settings (clés `payout_hook_url`, `payout_hook_secret`),
-- lisible du seul service_role — le contenant posé pour les notifications.
-- Jamais dans cette migration : un secret versionné est un secret brûlé.
-- Tant que la table n'a pas les deux clés, la tâche quotidienne ne fait rien,
-- en silence : une base de développement ne doit pas tenter de verser.
--
-- ── L'heure ─────────────────────────────────────────────────────────────────
-- 9 h 17 UTC, soit 5 h 17 à Ottawa (4 h 17 en hiver) : loin des heures
-- d'achat, et une minute « impaire » pour ne pas tomber avec les tâches que
-- tout le monde planifie à l'heure pile.
--
-- Déclenchable à la main pour un versement SURVEILLÉ, dans l'éditeur SQL :
--   select private.run_payouts_tick();
-- puis lire la réponse dans net._http_response. `run-payouts` est idempotente :
-- un appel de plus ne verse rien deux fois.

-- Déjà installé en production (notifications). Conditionnel pour qu'un
-- Postgres de test, qui ne l'a pas, puisse rejouer le script.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
end;
$$;

create or replace function private.run_payouts_tick()
returns bigint
language plpgsql
security definer
set search_path = private, public, extensions
as $$
declare
  v_url    text := private.setting('payout_hook_url');
  v_secret text := private.setting('payout_hook_secret');
begin
  if v_url is null or v_secret is null then
    raise notice 'run_payouts_tick : payout_hook_url / payout_hook_secret absents, rien n''est appele';
    return null;
  end if;
  -- Asynchrone : la réponse arrive dans net._http_response, sous l'identifiant
  -- renvoyé ici. C'est là qu'on lit le bilan (considered, paid, skipped…).
  return net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type',    'application/json',
                 'x-happyn-secret', v_secret
               ),
    body    := '{}'::jsonb,
    -- run-payouts relit chaque compte chez Stripe : plus lent qu'un envoi de
    -- notification.
    timeout_milliseconds := 60000
  );
end;
$$;

revoke all on function private.run_payouts_tick() from public, anon, authenticated;

-- pg_cron n'existe que sur Supabase (et pas sur un Postgres de test) : on
-- planifie seulement s'il est disponible. `cron.schedule` avec un nom déjà
-- utilisé remplace la tâche au lieu d'en créer une seconde — rejouer ce script
-- ne fait donc pas partir deux appels par jour.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.schedule(
      'happyn-payouts',
      '17 9 * * *',
      'select private.run_payouts_tick()'
    );
  else
    raise notice 'pg_cron indisponible : versements non planifies (base de test ?)';
  end if;
end;
$$;
