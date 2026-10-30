import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/config/observability.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Interrupteur « Notifications poussées », reflet de `profiles.push_enabled`.
///
/// La préférence vit en base, pas en local : elle suit la personne d'un
/// appareil à l'autre, et `send-push` la lit avant d'envoyer. Le jeton de
/// l'appareil n'est pas supprimé quand on coupe — on respecte juste le choix.
class PushToggleTile extends ConsumerStatefulWidget {
  const PushToggleTile({super.key});

  @override
  ConsumerState<PushToggleTile> createState() => _PushToggleTileState();
}

class _PushToggleTileState extends ConsumerState<PushToggleTile> {
  // Null tant qu'on n'a pas lu la valeur : on part « allumé » à l'affichage,
  // mais on ne persiste rien avant d'avoir chargé l'état réel.
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('push_enabled')
          .eq('id', uid)
          .maybeSingle();
      if (mounted) {
        setState(() => _enabled = (row?['push_enabled'] as bool?) ?? true);
      }
    } catch (e, st) {
      reportCaught(e, st, where: 'settings.loadPushPref');
      if (mounted) setState(() => _enabled = true);
    }
  }

  Future<void> _set(bool v) async {
    if (_busy) return;
    final previous = _enabled;
    // Bascule optimiste : l'interrupteur doit répondre tout de suite. On revient
    // en arrière si l'écriture échoue.
    setState(() {
      _enabled = v;
      _busy = true;
    });
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _busy = false);
      return;
    }
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'push_enabled': v}).eq('id', uid);
    } catch (e, st) {
      reportCaught(e, st, where: 'settings.setPushPref');
      if (mounted) setState(() => _enabled = previous);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final value = _enabled ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined,
              color: Colors.white.withValues(alpha: 0.85), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(l.pushNotificationsToggle,
                style: AppText.body.copyWith(color: Colors.white)),
          ),
          Switch(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: _enabled == null ? null : _set,
          ),
        ],
      ),
    );
  }
}
