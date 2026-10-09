import 'package:flutter/material.dart';
import 'package:happyn/core/config/observability.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/features/settings/legal_page_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Un document à accepter, tel que la base l'a présenté.
class PendingLegalDoc {
  final String slug;
  final String title;
  final String version;
  final bool previouslyAccepted;

  const PendingLegalDoc(
      this.slug, this.title, this.version, this.previouslyAccepted);

  /// Les documents que le compte connecté doit encore accepter.
  ///
  /// `null` si la base n'a pas pu répondre : l'appelant laisse alors entrer,
  /// et la question sera reposée au prochain lancement. Bloquer l'app sur une
  /// panne réseau punirait la personne pour un problème qui n'est pas le sien.
  /// [lang] : la langue de l'écran. La base renvoie le titre traduit quand la
  /// traduction porte la bonne version, l'anglais sinon.
  static Future<List<PendingLegalDoc>?> fetch(String lang) async {
    try {
      final data = await Supabase.instance.client
          .rpc('pending_legal_documents', params: {'p_locale': lang});
      return List<Map<String, dynamic>>.from(data as List)
          .map((r) => PendingLegalDoc(
                r['slug'] as String,
                (r['title'] as String?) ?? r['slug'] as String,
                r['version'] as String,
                r['previously_accepted'] == true,
              ))
          .toList();
    } catch (e, st) {
      reportCaught(e, st, where: 'consent.fetch');
      return null;
    }
  }
}

/// L'acceptation explicite des conditions, de la politique de confidentialité
/// et des règles de la communauté.
///
/// Une case à cocher PUIS un bouton, plutôt que « en continuant, tu acceptes » :
/// un geste volontaire, distinct de la simple poursuite, est ce qui fait d'un
/// clic un consentement qu'on peut opposer — au Québec en particulier.
///
/// L'acceptation est enregistrée par le serveur (`accept_legal_documents`),
/// avec son heure et pour les versions affichées ici : si un document change
/// entre l'affichage et le clic, le serveur refuse et l'écran se recharge.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, required this.docs, required this.onDone});

  final List<PendingLegalDoc> docs;
  final void Function(BuildContext context) onDone;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  late List<PendingLegalDoc> _docs = widget.docs;
  bool _checked = false;
  bool _saving = false;

  bool get _isUpdate => _docs.any((d) => d.previouslyAccepted);

  String _name(AppLocalizations l, PendingLegalDoc d) => switch (d.slug) {
        'terms' => l.legalTerms,
        'privacy' => l.legalPrivacy,
        'community' => l.legalCommunity,
        _ => d.title,
      };

  Future<void> _accept() async {
    final l = AppLocalizations.of(context);
    if (!_checked) {
      showAppSnack(context, l.consentNeedCheck);
      return;
    }
    setState(() => _saving = true);
    try {
      // La langue part avec l'accord : la base la note si une traduction de
      // cette version existe — c'est le texte que la personne a lu.
      await Supabase.instance.client.rpc('accept_legal_documents', params: {
        'p_versions': {for (final d in _docs) d.slug: d.version},
        'p_locale': Localizations.localeOf(context).languageCode,
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (e.message.contains('version_changed')) {
        // Un document a changé pendant que l'écran était ouvert : on montre la
        // nouvelle liste, et la case se décoche — l'accord donné portait sur
        // un autre texte.
        final fresh = await PendingLegalDoc.fetch(
            Localizations.localeOf(context).languageCode);
        if (!mounted) return;
        setState(() {
          if (fresh != null && fresh.isNotEmpty) _docs = fresh;
          _checked = false;
          _saving = false;
        });
        showAppSnack(context, l.consentVersionChanged);
        return;
      }
      reportCaught(e, StackTrace.current, where: 'consent.accept');
      setState(() => _saving = false);
      showAppSnack(context, l.couldNotSaveRetry);
      return;
    } catch (e, st) {
      reportCaught(e, st, where: 'consent.accept');
      if (mounted) {
        setState(() => _saving = false);
        showAppSnack(context, l.couldNotSaveRetry);
      }
      return;
    }
    if (mounted) widget.onDone(context);
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 56, bottom: 16),
                    children: [
                      Text(
                        _isUpdate ? l.consentTitleUpdate : l.consentTitle,
                        style: AppText.display
                            .copyWith(fontSize: 28, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isUpdate ? l.consentIntroUpdate : l.consentIntro,
                        style: AppText.body
                            .copyWith(color: AppColors.textMed, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      for (final d in _docs) _docRow(l, d),
                    ],
                  ),
                ),
                // La case : un geste distinct du bouton, et toute la ligne est
                // cliquable — une case de 18 points seule se rate au pouce.
                InkWell(
                  onTap: _saving
                      ? null
                      : () => setState(() => _checked = !_checked),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _checked,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _checked = v ?? false),
                          activeColor: AppColors.primary,
                          side: BorderSide(color: AppColors.textLow, width: 1.5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(l.consentCheckbox,
                              style: AppText.body.copyWith(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _saving ? null : _accept,
                  child: AnimatedOpacity(
                    opacity: _checked ? 1 : 0.45,
                    duration: const Duration(milliseconds: 150),
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
                          : Text(l.consentAccept,
                              style:
                                  AppText.h3.copyWith(color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Refuser reste possible : on se déconnecte. Sans cette issue,
                // l'écran serait une impasse — et un accord obtenu faute
                // d'alternative vaut moins.
                Center(
                  child: TextButton(
                    onPressed: _saving ? null : _signOut,
                    child: Text(l.signOut,
                        style:
                            AppText.bodySm.copyWith(color: AppColors.textMed)),
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

  Widget _docRow(AppLocalizations l, PendingLegalDoc d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => LegalPageScreen(docId: d.slug),
          )),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                const Icon(Icons.description_outlined,
                    color: AppColors.lavender, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name(l, d),
                          style: AppText.h5.copyWith(color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(
                        d.previouslyAccepted
                            ? '${l.consentUpdated} · ${d.version}'
                            : d.version,
                        style: AppText.micro,
                      ),
                    ],
                  ),
                ),
                Text(l.consentRead,
                    style: AppText.smallBold
                        .copyWith(color: AppColors.lavender)),
                const Icon(Icons.chevron_right,
                    color: AppColors.lavender, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
