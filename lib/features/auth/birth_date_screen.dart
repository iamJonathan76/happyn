import 'package:flutter/material.dart';
import 'package:happyn/core/config/observability.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/age.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Demande la date de naissance à un compte qui n'en a pas.
///
/// L'inscription par e-mail la demande dans son formulaire ; celle par Google
/// ne la demandait nulle part — Google ne la fournit pas. Ces comptes n'avaient
/// donc pas d'âge, et toutes les règles qui en dépendent les laissaient
/// passer : le minimum de 14 ans pour avoir un compte, l'âge minimum d'un
/// événement, les 18 ans pour organiser. Cet écran passe avant tout le reste
/// tant que la date manque, y compris pour les comptes déjà créés.
class BirthDateScreen extends StatefulWidget {
  const BirthDateScreen({super.key, required this.onDone});

  /// Où aller ensuite. Reçoit le contexte de cet écran.
  final void Function(BuildContext context) onDone;

  /// La date manque-t-elle au compte connecté ?
  static bool isMissing() => currentUserDob() == null;

  @override
  State<BirthDateScreen> createState() => _BirthDateScreenState();
}

class _BirthDateScreenState extends State<BirthDateScreen> {
  DateTime? _dob;
  bool _saving = false;

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: AppLocalizations.of(context).selectDateOfBirth,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.sheet,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _continue() async {
    final l = AppLocalizations.of(context);
    final dob = _dob;
    if (dob == null) {
      showAppSnack(context, l.errEnterDob);
      return;
    }
    if ((ageFromDob(dob) ?? 0) < kMinAccountAge) {
      await _refuseTooYoung();
      return;
    }

    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final iso = dob.toIso8601String().split('T').first; // YYYY-MM-DD
    try {
      // Aux deux endroits, comme l'inscription par e-mail : l'app lit les
      // métadonnées (`currentUserDob`), le serveur lit le profil (transfert de
      // billet vers un mineur, par exemple).
      await client.auth.updateUser(UserAttributes(data: {'date_of_birth': iso}));
      await client
          .from('profiles')
          .update({'date_of_birth': iso}).eq('id', client.auth.currentUser!.id);
    } catch (e, st) {
      reportCaught(e, st, where: 'birthDate.save');
      if (mounted) {
        setState(() => _saving = false);
        showAppSnack(context, l.couldNotSaveRetry);
      }
      return;
    }
    if (mounted) widget.onDone(context);
  }

  /// Moins de 14 ans : le compte est supprimé, pas seulement fermé. La
  /// politique de confidentialité promet d'effacer ce qu'on détient sur un
  /// enfant de moins de 14 ans — le nom et l'adresse reçus de Google compris.
  Future<void> _refuseTooYoung() async {
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.sheet,
        title: Text(l.dobTooYoungTitle,
            style: AppText.h3.copyWith(color: Colors.white)),
        content: Text(l.dobTooYoungBody,
            style: AppText.body.copyWith(color: AppColors.textMed)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.dobTooYoungOk),
          ),
        ],
      ),
    );
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    try {
      await client.functions.invoke('delete-account');
    } catch (e, st) {
      // Un compte tout juste créé n'a rien qui bloque la suppression ; si elle
      // échoue quand même, on le saura, et la personne est déconnectée.
      reportCaught(e, st, where: 'birthDate.deleteTooYoung');
    }
    await client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (_) => false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (_) => false);
    }
  }

  String _format(DateTime d) =>
      MaterialLocalizations.of(context).formatMediumDate(d);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Pas de retour : derrière, il n'y a que la connexion, déjà faite.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 56),
                Text(l.dobTitle,
                    style: AppText.display
                        .copyWith(fontSize: 28, color: Colors.white)),
                const SizedBox(height: 10),
                Text(l.dobWhy,
                    style: AppText.body
                        .copyWith(color: AppColors.textMed, height: 1.5)),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: _saving ? null : _pick,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 17),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cake_outlined,
                            color: AppColors.textLow, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          _dob == null ? l.dateOfBirth : _format(_dob!),
                          style: TextStyle(
                            color:
                                _dob == null ? AppColors.textLow : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _saving ? null : _continue,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(l.onbContinue,
                            style: AppText.h3.copyWith(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
                // Une issue pour qui ne veut pas la donner : sans elle, l'écran
                // serait une impasse.
                Center(
                  child: TextButton(
                    onPressed: _saving ? null : _signOut,
                    child: Text(l.signOut,
                        style: AppText.bodySm
                            .copyWith(color: AppColors.textMed)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
