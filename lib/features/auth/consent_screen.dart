import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/legal/legal_content.dart';
import 'package:happyn/core/providers/legal_provider.dart';
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
/// et des règles de la communauté — sur le modèle de Google.
///
/// Un seul texte qui défile : le résumé « En bref » de chaque document, tiré
/// du document lui-même, avec un lien vers le texte complet. Le bouton
/// « J'accepte » est à la FIN du texte, pas flottant : on ne l'atteint qu'en
/// l'ayant fait défiler, et juste au-dessus une phrase dit exactement ce qu'on
/// accepte, versions comprises, et une case à cocher qui active le bouton :
/// deux gestes volontaires, après une présentation claire, plutôt qu'un
/// simple « continuer ».
///
/// Forcer à dérouler les documents COMPLETS (20 000 caractères) aurait été
/// pire : on défile sans lire, et un défilement ne prouve pas une lecture.
///
/// L'acceptation est enregistrée par le serveur (`accept_legal_documents`),
/// avec son heure, la langue lue et pour les versions affichées ici : si un
/// document change entre l'affichage et le clic, le serveur refuse et l'écran
/// se recharge.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key, required this.docs, required this.onDone});

  final List<PendingLegalDoc> docs;
  final void Function(BuildContext context) onDone;

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  late List<PendingLegalDoc> _docs = widget.docs;
  final _scroll = ScrollController();
  bool _checked = false;
  bool _saving = false;

  /// Arrivé en bas : la pastille « Lire la suite » disparaît. Vrai aussi
  /// quand tout tient à l'écran.
  bool _atEnd = false;

  bool get _isUpdate => _docs.any((d) => d.previouslyAccepted);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_checkEnd);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkEnd());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _checkEnd() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final atEnd = p.pixels >= p.maxScrollExtent - 24;
    if (atEnd != _atEnd) setState(() => _atEnd = atEnd);
  }

  /// Un écran plus bas, pas jusqu'en bas : sauter directement au bouton
  /// reviendrait à sauter la lecture.
  void _keepReading() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    _scroll.animateTo(
      (p.pixels + p.viewportDimension * 0.8).clamp(0, p.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  String _name(AppLocalizations l, PendingLegalDoc d) => switch (d.slug) {
        'terms' => l.legalTerms,
        'privacy' => l.legalPrivacy,
        'community' => l.legalCommunity,
        _ => d.title,
      };

  /// Le résumé « En bref » du document, dans la langue de l'écran.
  ///
  /// Seulement s'il correspond à la version qu'on fait accepter : un résumé
  /// d'une autre version serait le résumé d'un autre texte. Sans résumé, le
  /// lien vers le document complet reste — l'accord ne repose jamais sur un
  /// résumé absent.
  LegalSection? _summary(PendingLegalDoc d, String lang) {
    final docs = ref.watch(legalDocsProvider).asData?.value;
    final raw = docs?.cast<Map<String, dynamic>?>().firstWhere(
        (x) => x?['slug'] == d.slug,
        orElse: () => null);
    if (raw == null || raw['version'] != d.version) return null;
    final shown = localizedLegalDoc(raw, lang);
    final sections = parseLegalMarkdown((shown['content'] ?? '') as String);
    if (sections.isEmpty) return null;
    return sections.firstWhere(
      (s) => s.heading == 'In short' || s.heading == 'En bref',
      orElse: () => sections.first,
    );
  }

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
        // Un document a changé pendant que l'écran était ouvert : on recharge
        // la liste ET les textes, et on remonte en haut — l'accord donné
        // portait sur un autre texte.
        ref.invalidate(legalDocsProvider);
        final fresh = await PendingLegalDoc.fetch(
            Localizations.localeOf(context).languageCode);
        if (!mounted) return;
        setState(() {
          if (fresh != null && fresh.isNotEmpty) _docs = fresh;
          _checked = false; // l'accord portait sur un autre texte
          _saving = false;
        });
        if (_scroll.hasClients) _scroll.jumpTo(0);
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
    final lang = Localizations.localeOf(context).languageCode;
    // Le contenu peut changer de hauteur (textes chargés après coup) : on
    // revérifie la fin après chaque construction.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkEnd());

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                children: [
                  Text(
                    _isUpdate ? l.consentTitleUpdate : l.consentTitle,
                    style: AppText.display
                        .copyWith(fontSize: 28, color: Colors.white, height: 1.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isUpdate ? l.consentIntroUpdate : l.consentIntro,
                    style: AppText.body
                        .copyWith(color: AppColors.textMed, height: 1.5),
                  ),
                  for (final d in _docs) _docBlock(l, d, lang),
                  const SizedBox(height: 28),
                  Text(
                    l.consentStatement(_docs
                        .map((d) => '${_name(l, d)} (${d.version})')
                        .join(', ')),
                    style: AppText.bodySm
                        .copyWith(color: AppColors.textLow, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  // Toute la ligne est cliquable : une case de 18 points
                  // seule se rate au pouce.
                  InkWell(
                    onTap: _saving
                        ? null
                        : () => setState(() => _checked = !_checked),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _checked,
                            onChanged: _saving
                                ? null
                                : (v) => setState(() => _checked = v ?? false),
                            activeColor: AppColors.primary,
                            side: BorderSide(
                                color: AppColors.textLow, width: 1.5),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(l.consentCheckbox,
                                style: AppText.body
                                    .copyWith(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Refuser reste possible : on se déconnecte. Sans cette
                      // issue, un accord obtenu faute d'alternative vaut moins.
                      TextButton(
                        onPressed: _saving ? null : _signOut,
                        child: Text(l.signOut,
                            style: AppText.bodySm
                                .copyWith(color: AppColors.textMed)),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _saving ? null : _accept,
                        child: AnimatedOpacity(
                          opacity: _checked ? 1 : 0.4,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(26),
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
                                      AppText.h4.copyWith(color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Tant qu'on n'est pas en bas : une pastille qui fait descendre
              // d'un écran, et un fondu qui dit qu'il y a une suite.
              if (!_atEnd)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 96,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x0008080F), AppColors.background],
                        ),
                      ),
                    ),
                  ),
                ),
              if (!_atEnd)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _keepReading,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l.consentMore,
                                style: AppText.smallBold
                                    .copyWith(color: Colors.white)),
                            const SizedBox(width: 6),
                            const Icon(Icons.keyboard_arrow_down,
                                color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _docBlock(AppLocalizations l, PendingLegalDoc d, String lang) {
    final summary = _summary(d, lang);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_name(l, d), style: AppText.h2.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            d.previouslyAccepted
                ? '${l.consentUpdated} · ${d.version}'
                : d.version,
            style: AppText.micro,
          ),
          if (summary != null) ...[
            const SizedBox(height: 12),
            for (final p in summary.paragraphs) ...[
              Text(p, style: AppText.body.copyWith(height: 1.5)),
              const SizedBox(height: 8),
            ],
            for (final b in summary.bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 10),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.lavender,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(b, style: AppText.body.copyWith(height: 1.5)),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => LegalPageScreen(docId: d.slug),
            )),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.consentReadFull,
                      style:
                          AppText.smallBold.copyWith(color: AppColors.lavender)),
                  const Icon(Icons.chevron_right,
                      color: AppColors.lavender, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
