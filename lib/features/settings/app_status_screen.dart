import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/app_status/app_status.dart';
import 'package:happyn/core/config/observability.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Réservé aux administrateurs : maintenance et version minimale.
///
/// L'écran n'est qu'un formulaire. Le droit est vérifié par
/// `admin_set_app_status`, en base ; un compte ordinaire qui forcerait
/// l'ouverture n'obtiendrait que `not_admin`.
class AppStatusScreen extends ConsumerStatefulWidget {
  const AppStatusScreen({super.key});

  @override
  ConsumerState<AppStatusScreen> createState() => _AppStatusScreenState();
}

class _AppStatusScreenState extends ConsumerState<AppStatusScreen> {
  final _fr = TextEditingController();
  final _en = TextEditingController();
  final _min = TextEditingController();
  bool _maintenance = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _fr.dispose();
    _en.dispose();
    _min.dispose();
    super.dispose();
  }

  void _fill(AppStatus s) {
    if (_loaded) return;
    _loaded = true;
    _maintenance = s.maintenance;
    _fr.text = s.messageFr ?? '';
    _en.text = s.messageEn ?? '';
    _min.text = s.minVersion ?? '';
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final min = _min.text.trim();
    if (min.isNotEmpty && !RegExp(r'^\d+(\.\d+){0,2}$').hasMatch(min)) {
      showAppSnack(context, l.appStatusBadVersion);
      return;
    }
    // Activer la maintenance coupe l'app pour tout le monde sauf les admins :
    // on demande confirmation, une fausse manipulation se verrait aussitôt.
    final current = ref.read(appStatusProvider).asData?.value;
    if (_maintenance && current?.maintenance != true) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.sheet,
          title: Text(l.appStatusConfirmTitle, style: AppText.h3),
          content: Text(l.appStatusConfirmBody, style: AppText.bodySm),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l.cancel)),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l.appStatusConfirmAction,
                    style: const TextStyle(color: AppColors.error))),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.rpc('admin_set_app_status', params: {
        'p_maintenance': _maintenance,
        'p_message_fr': _fr.text,
        'p_message_en': _en.text,
        'p_min_version': min,
      });
      if (mounted) showAppSnack(context, l.appStatusSaved);
    } catch (e, st) {
      reportCaught(e, st, where: 'appStatus.save');
      if (mounted) showAppSnack(context, l.couldNotSaveRetry);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = ref.watch(appStatusProvider).asData?.value;
    if (status != null) _fill(status);
    final version = ref.watch(appVersionProvider).asData?.value ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(l.appStatusTitle, style: AppText.h3),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                  decoration: BoxDecoration(
                    color: _maintenance
                        ? AppColors.error.withValues(alpha: 0.12)
                        : AppColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _maintenance ? AppColors.error : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.appStatusMaintenance,
                                style: AppText.bodySm.copyWith(
                                    color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(l.appStatusMaintenanceHint, style: AppText.small),
                          ],
                        ),
                      ),
                      Switch(
                        value: _maintenance,
                        activeTrackColor: AppColors.error,
                        onChanged: (v) => setState(() => _maintenance = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                AppLabel(l.appStatusMessageFr),
                TextField(
                  controller: _fr,
                  maxLength: 300,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: appInputDecoration(l.maintenanceBody)
                      .copyWith(counterStyle: AppText.micro),
                ),
                const SizedBox(height: 8),
                AppLabel(l.appStatusMessageEn),
                TextField(
                  controller: _en,
                  maxLength: 300,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: appInputDecoration('We\'re making a quick update — back very soon.')
                      .copyWith(counterStyle: AppText.micro),
                ),
                const SizedBox(height: 16),
                AppLabel(l.appStatusMinVersion),
                TextField(
                  controller: _min,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: appInputDecoration('1.0.0'),
                ),
                const SizedBox(height: 6),
                Text(l.appStatusMinVersionHint(version), style: AppText.small),
                const SizedBox(height: 28),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.action,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(l.saveChanges, style: AppText.h3),
                  ),
                ),
              ],
            ),
    );
  }
}
