import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/email.dart';
import 'package:happyn/core/utils/support.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Changement d'adresse e-mail.
///
/// L'adresse n'est pas un champ de profil comme les autres : c'est
/// l'identifiant de connexion et le canal de recuperation du compte. On ne
/// peut donc pas l'enregistrer en meme temps que la ville et la bio, d'ou cet
/// ecran separe.
///
/// Le changement ne prend effet qu'apres confirmation — un lien envoye a
/// l'ancienne adresse ET un a la nouvelle quand `secure_email_change` est
/// actif cote Supabase (c'est le defaut, et ce qui empeche quelqu'un qui
/// passe devant un telephone deverrouille de s'approprier le compte en
/// changeant l'adresse). L'ecran le dit, parce que l'attente est longue et
/// qu'autrement elle ressemble a une panne : on tape une adresse, on valide,
/// et rien ne change.
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _supabase = Supabase.instance.client;
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _sending = false;
  String? _error;

  /// Le changement a ete demande : l'ecran passe en mode « verifie ta boite »
  /// plutot que de revenir en arriere. Repartir sur les reglages laisserait
  /// croire que c'est fait, alors que tout reste a confirmer.
  bool _sent = false;

  String get _current => _supabase.auth.currentUser?.email ?? '';

  /// Adresse dont le changement est deja en attente de confirmation, s'il y en
  /// a une. Supabase la garde a part tant que les liens ne sont pas cliques.
  String? get _pending {
    final v = _supabase.auth.currentUser?.newEmail;
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Si le compte peut se connecter par mot de passe. Un compte cree via
  /// Google n'en a pas : changer son adresse ici ne change pas la facon dont
  /// il se connecte, et le taire laisserait croire le contraire.
  ///
  /// `null` quand la reponse est inconnue — les identites ne sont pas toujours
  /// renvoyees avec l'utilisateur. On se taît alors, plutot que d'annoncer
  /// « tu te connectes avec Google » a quelqu'un qui a un mot de passe.
  bool? get _hasPassword {
    final ids = _supabase.auth.currentUser?.identities;
    if (ids == null || ids.isEmpty) return null;
    return ids.any((i) => i.provider == 'email');
  }

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _message(AppLocalizations l, EmailProblem p) => switch (p) {
        EmailProblem.empty => l.emailChangeNeedAddress,
        EmailProblem.malformed => l.emailChangeMalformed,
        EmailProblem.unchanged => l.emailChangeSameAddress,
        EmailProblem.mismatch => l.emailChangeMismatch,
      };

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final next = normalizeEmail(_newController.text);

    final problem = emailChangeProblem(
      current: _current,
      next: _newController.text,
      confirm: _confirmController.text,
    );
    if (problem != null) {
      setState(() => _error = _message(l, problem));
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await _supabase.auth.updateUser(
        UserAttributes(email: next),
        // Ou atterrit le lien de confirmation. Doit etre declaree dans
        // Supabase (Authentication > URL Configuration) : sans cela la
        // redirection est refusee, ce qui empeche de faire pointer le lien
        // vers un site tiers.
        emailRedirectTo: kEmailChangeUrl,
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
    } on AuthException catch (e) {
      debugPrint('CHANGE_EMAIL AuthException: ${e.statusCode} ${e.message}');
      if (!mounted) return;
      setState(() {
        _sending = false;
        // Adresse deja prise par un autre compte : le dire reviendrait a
        // confirmer qui est inscrit sur HAPPYN. On renvoie donc le meme
        // message que pour un refus quelconque — l'utilisateur de bonne foi
        // s'en apercoit de toute facon, le courriel n'arrivant pas.
        _error = _tooManyRequests(e)
            ? l.emailChangeTooSoon
            : l.emailChangeFailed;
      });
    } catch (e) {
      debugPrint('CHANGE_EMAIL exception: $e');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = l.emailChangeFailed;
      });
    }
  }

  /// Supabase limite les envois. Une attente n'est pas un echec, et proposer
  /// de « reessayer » tout de suite ferait tourner l'utilisateur en rond.
  ///
  /// On regarde `code` en premier (stable, documente) et on ne retombe sur le
  /// texte du message que pour les anciennes reponses qui n'en portaient pas.
  bool _tooManyRequests(AuthException e) {
    const codes = {'over_email_send_rate_limit', 'over_request_rate_limit'};
    if (e.code != null && codes.contains(e.code)) return true;
    if (e.statusCode == '429') return true;
    final m = e.message.toLowerCase();
    return m.contains('security purposes') || m.contains('rate limit');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l.emailChangeTitle, style: AppText.h2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: _sent ? _confirmationStep(l) : _formStep(l),
      ),
    );
  }

  // ── Etape 1 : la demande ──────────────────────────────────────────────────

  List<Widget> _formStep(AppLocalizations l) {
    final pending = _pending;

    return [
      AppLabel(l.emailChangeCurrent),
      _readOnlyRow(_current, Icons.mail_outline),

      // Un changement deja en attente. Sans cette ligne, l'utilisateur qui
      // revient ne sait pas si sa demande precedente est partie, et en relance
      // une — ce que la limite d'envoi refusera, sans expliquer pourquoi.
      if (pending != null) ...[
        const SizedBox(height: 14),
        _notice(
          Icons.schedule,
          l.emailChangePendingNotice(pending),
          AppColors.amber,
        ),
      ],

      const SizedBox(height: 22),
      AppLabel(l.emailChangeNew),
      TextField(
        controller: _newController,
        enabled: !_sending,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration:
            appInputDecoration(l.emailChangeNewHint, icon: Icons.alternate_email),
      ),

      const SizedBox(height: 16),
      AppLabel(l.emailChangeConfirm),
      TextField(
        controller: _confirmController,
        enabled: !_sending,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          if (!_sending) _submit();
        },
        style: const TextStyle(color: Colors.white, fontSize: 14),
        // L'erreur s'affiche sous le second champ : c'est le dernier endroit
        // regarde avant de valider, et toutes nos erreurs (format, doublon,
        // adresse identique) se corrigent en retapant.
        decoration: appInputDecoration(l.emailChangeConfirmHint,
                icon: Icons.alternate_email)
            .copyWith(errorText: _error, errorMaxLines: 3),
      ),

      const SizedBox(height: 20),
      _notice(Icons.info_outline, l.emailChangeHowItWorks, AppColors.lavender),

      if (_hasPassword == false) ...[
        const SizedBox(height: 12),
        _notice(Icons.login, l.emailChangeOauthNotice, AppColors.textLow),
      ],

      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _sending ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _sending
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white),
                )
              : Text(l.emailChangeSend,
                  style: AppText.h4.copyWith(color: Colors.white)),
        ),
      ),
    ];
  }

  // ── Etape 2 : ce qu'il reste a faire ──────────────────────────────────────

  List<Widget> _confirmationStep(AppLocalizations l) {
    final next = normalizeEmail(_newController.text);

    return [
      const SizedBox(height: 10),
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_unread_outlined,
              color: AppColors.lavender, size: 30),
        ),
      ),
      const SizedBox(height: 20),
      Center(child: Text(l.emailChangeSentTitle, style: AppText.h3)),
      const SizedBox(height: 10),
      Text(
        l.emailChangeSentBody,
        textAlign: TextAlign.center,
        style: AppText.bodySm.copyWith(height: 1.55),
      ),
      const SizedBox(height: 22),

      // Les deux adresses, en clair. C'est ici qu'on repere une faute de
      // frappe, pendant que le changement n'est pas encore acquis.
      _step(1, l.emailChangeStepOld(_current)),
      _step(2, l.emailChangeStepNew(next)),

      const SizedBox(height: 18),
      _notice(Icons.lock_outline, l.emailChangeUntilThen, AppColors.textLow),

      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(l.emailChangeDone,
              style: AppText.h4.copyWith(color: Colors.white)),
        ),
      ),
    ];
  }

  // ── Briques ───────────────────────────────────────────────────────────────

  Widget _readOnlyRow(String text, IconData icon) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textLow, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: AppText.body)),
          ],
        ),
      );

  Widget _notice(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: AppText.small.copyWith(height: 1.5)),
            ),
          ],
        ),
      );

  Widget _step(int n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Text('$n',
                  style: AppText.microBold.copyWith(color: AppColors.lavender)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(text,
                    style: AppText.bodySm.copyWith(height: 1.5)),
              ),
            ),
          ],
        ),
      );
}
