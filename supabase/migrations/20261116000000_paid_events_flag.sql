-- Drapeau « événements payants ouverts ».
--
-- HAPPYN se lance en GRATUIT (docs/LANCEMENT.md § 0) : au lancement, personne ne
-- peut créer de billet payant. Le payant est entièrement codé mais dort derrière
-- ce drapeau, qu'on bascule le jour de l'ouverture (« le boom ») sans rien
-- redéployer : `select public.admin_set_paid_events(true);`.
--
-- Le drapeau vit sur `app_status` (une ligne, lisible par tous, déjà en temps
-- réel) mais il est DÉCOUPLÉ de `admin_set_app_status` : cette fonction réécrit
-- l'état complet à chaque appel, donc basculer la maintenance aurait refermé le
-- payant par effet de bord. D'où une porte d'écriture dédiée.
--
-- Défaut : FAUX. Les événements déjà en base ne sont pas touchés (le garde-fou
-- ne s'applique qu'aux écritures, pas aux lignes existantes).

alter table public.app_status
  add column if not exists paid_events_enabled boolean not null default false;

-- Au cas où la ligne unique n'existe pas encore (bases neuves) : la poser, sans
-- écraser un drapeau déjà positionné.
insert into public.app_status (id) values (true) on conflict (id) do nothing;

-- Lecture pour l'app : masque la billetterie payante quand c'est faux. `stable`,
-- lisible par tous — l'écran de création doit pouvoir la lire avant la vente.
create or replace function public.paid_events_enabled()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce((select paid_events_enabled from public.app_status where id), false);
$$;

revoke all on function public.paid_events_enabled() from public;
grant execute on function public.paid_events_enabled() to anon, authenticated, service_role;

-- Porte d'écriture dédiée. Réservée aux admins, comme `admin_set_app_status`,
-- et séparée d'elle exprès (voir en-tête).
create or replace function public.admin_set_paid_events(p_on boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;
  update public.app_status
     set paid_events_enabled = coalesce(p_on, false),
         updated_at = now(),
         updated_by = auth.uid()
   where id;
end;
$$;

revoke all on function public.admin_set_paid_events(boolean) from public, anon;
grant execute on function public.admin_set_paid_events(boolean) to authenticated, service_role;

-- Le vrai verrou : même un appel direct à l'API (en contournant l'app qui masque
-- le champ) ne peut pas créer un billet payant tant que le drapeau est faux.
-- C'est la base qui garde l'argent, pas l'écran.
create or replace function public.guard_paid_events()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- On ne bloque que la MISE EN PLACE d'un prix > 0 : créer un tarif payant, ou
  -- faire passer un tarif de gratuit à payant. Modifier un tarif déjà payant
  -- (quantité, nom) reste permis — sinon on figerait d'anciens événements le
  -- jour où le drapeau serait refermé.
  if coalesce(new.price, 0) > 0
     and (tg_op = 'INSERT' or new.price is distinct from old.price)
     and not public.paid_events_enabled()
  then
    raise exception 'paid_events_disabled'
      using hint = 'Les événements payants ne sont pas encore ouverts.';
  end if;
  return new;
end;
$$;

drop trigger if exists ticket_types_guard_paid on public.ticket_types;
create trigger ticket_types_guard_paid
  before insert or update on public.ticket_types
  for each row execute function public.guard_paid_events();
