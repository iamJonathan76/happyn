-- Fonctions TRIGGER : retirer le droit de les appeler directement.
--
-- Ces 5 fonctions ne servent QUE de declencheurs (return trigger). Supabase
-- leur a laisse EXECUTE pour anon ET authenticated : n'importe qui pouvait donc
-- les invoquer comme une RPC. Ce sont des SECURITY DEFINER — appelees a la main
-- avec un NEW/TG_OP forge, elles s'executent avec les droits du proprietaire.
-- Les triggers, eux, n'ont pas besoin de ce droit : ils s'executent dans le
-- cadre du DML, pas comme un appel de l'utilisateur. On retire donc EXECUTE a
-- tout le monde ; les declencheurs continuent de tourner, plus personne ne les
-- appelle directement. (Les fonctions trigger plus recentes etaient deja
-- verrouillees ; ces 5 datent d'avant cette discipline.)

revoke execute on function public.handle_new_user()        from public, anon, authenticated;
revoke execute on function public.notify_event_change()    from public, anon, authenticated;
revoke execute on function public.prevent_self_admin()     from public, anon, authenticated;
revoke execute on function public.reports_fill_label()     from public, anon, authenticated;
revoke execute on function public.sync_event_attendance()  from public, anon, authenticated;
