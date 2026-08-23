import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/core/providers/admin_provider.dart';
import 'package:happyn/core/utils/support.dart';
import 'package:happyn/features/settings/moderation_screen.dart';
import 'package:happyn/features/settings/edit_profile_screen.dart';
import 'package:happyn/features/ticketing/my_tickets_screen.dart';
import 'package:happyn/features/settings/legal_page_screen.dart';
import 'package:happyn/features/settings/delete_account_screen.dart';
import 'package:happyn/features/settings/blocked_users_screen.dart';
import 'package:happyn/core/providers/legal_provider.dart';
import 'package:happyn/core/providers/locale_provider.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Écran Settings complet, suivant la structure du « Account & Settings » doc.
/// Les items fonctionnels naviguent ; ceux pas encore prêts affichent
/// « Coming soon » et portent un petit badge.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String appVersion = '1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legalDocs = ref.watch(legalDocsProvider).asData?.value;
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
        title: Text(
          l.settingsTitle,
          style: AppText.h2.copyWith(color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Account ───────────────────────────────────────────────
          _section(l.sectionAccount),
          _tile(context, Icons.person_outline, l.editProfile,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const EditProfileScreen()))),
          _languageTile(context, ref, l),

          // ── Social ────────────────────────────────────────────────
          // « Amis », « Abonnements » et « Abonnés » ont ete retires : ils
          // annoncaient « bientot » alors que les compteurs et le graphe
          // vivent deja sur le profil. Une ligne qui dit « bientot » pour une
          // chose deja faite fait passer l'app pour inachevee, et apprend a
          // l'utilisateur a ne plus lire les libelles.
          _section(l.sectionSocial),
          _tile(context, Icons.block, l.blockedUsers,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const BlockedUsersScreen()))),

          // ── Mon activité ──────────────────────────────────────────
          // Mes billets existe vraiment : on y mene, au lieu de promettre un
          // « historique » qui serait le meme ecran.
          _section(l.sectionMyActivity),
          _tile(context, Icons.confirmation_number_outlined, l.myTicketsTitle,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MyTicketsScreen()))),

          // ── Moderation ────────────────────────────────────────────
          // N'apparait que pour un administrateur. Ce n'est pas une
          // protection : chaque action est revérifiée en base.
          if (ref.watch(isAdminProvider).asData?.value == true) ...[
            _section(l.moderation),
            _tile(context, Icons.gavel_outlined, l.moderationQueue,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ModerationScreen()))),
          ],

          // ── Modération (administrateurs) ──────────────────────────
          // L'entree n'apparait que pour un administrateur, mais ce n'est pas
          // ce qui protege : chaque action est revérifiée en base
          // (`i_am_admin`). Forcer l'ecran a s'ouvrir ne donnerait qu'une file
          // vide et des erreurs `not_admin`.
          if (ref.watch(isAdminProvider).asData?.value == true) ...[
            _section(l.moderation),
            _tile(context, Icons.shield_outlined, l.moderationQueue,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ModerationScreen()))),
          ],

          // ── Assistance ────────────────────────────────────────────
          // Une seule ligne, qui ouvre vraiment un courriel. Apple veut un
          // moyen de contact joignable ; un centre d'aide vide n'en est pas un.
          _section(l.sectionSupport),
          _tile(context, Icons.support_agent, l.contactSupport,
              onTap: () => _contactSupport(context, l)),

          // ── Legal (piloté par la DB : legal_documents) ────────────
          _section(l.sectionLegal),
          ...(legalDocs != null && legalDocs.isNotEmpty
                  ? legalDocs.map((d) => _legal(
                      context,
                      _legalIcon(d['slug'] as String),
                      (d['title'] ?? 'Document') as String,
                      d['slug'] as String))
                  : _fallbackLegalTiles(context))
              .toList(),

          // ── About ─────────────────────────────────────────────────
          _section(l.sectionAbout),
          _staticTile(Icons.info_outline, l.appVersion, appVersion),
          _tile(context, Icons.favorite_border, l.aboutHappyn,
              onTap: () => _showAbout(context)),

          // ── Account Actions ───────────────────────────────────────
          _section(l.sectionAccountActions),
          _danger(context, Icons.logout, l.signOut,
              onTap: () => _signOut(context)),
          _danger(context, Icons.delete_outline, l.deleteAccount,
              onTap: () => _deleteAccount(context)),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  void _deleteAccount(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const DeleteAccountScreen()));
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('HAPPYN',
            style: AppText.h4.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
        content: Text(
          AppLocalizations.of(context).aboutHappynBody(appVersion),
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).close,
                style: AppText.body.copyWith(color: AppColors.lavender)),
          ),
        ],
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  /// Ouvre l'app de courriel. Si le telephone n'en a aucune, on affiche
  /// l'adresse en clair : laisser l'utilisateur sans rien serait le pire des
  /// deux mondes — on lui a promis un contact et il ne l'obtient pas.
  Future<void> _contactSupport(
      BuildContext context, AppLocalizations l) async {
    final ok = await contactSupport(subject: 'HAPPYN — ${l.contactSupport}');
    if (!ok && context.mounted) {
      showAppSnack(context, l.supportNoMailApp(kSupportEmail));
    }
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(
          title.toUpperCase(),
          style: AppText.smallBold.copyWith(color: AppColors.lavender, letterSpacing: 1),
        ),
      );

  Widget _tile(BuildContext context, IconData icon, String label,
          {required VoidCallback onTap}) =>
      _row(icon, label, onTap: onTap, trailing: _chevron());

  Widget _legal(
          BuildContext context, IconData icon, String label, String docId) =>
      _row(icon, label,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => LegalPageScreen(docId: docId))),
          trailing: _chevron());

  /// Ligne « Language » avec la langue courante + ouverture du sélecteur.
  Widget _languageTile(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    final current = ref.watch(localeProvider);
    final label = current?.languageCode == 'fr'
        ? l.languageFrench
        : current?.languageCode == 'en'
            ? l.languageEnglish
            : Localizations.localeOf(context).languageCode == 'fr'
                ? l.languageFrench
                : l.languageEnglish;
    return _row(
      Icons.language,
      l.language,
      onTap: () => _pickLanguage(context, ref, l),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: AppText.bodySm.copyWith(color: AppColors.textLow)),
          const SizedBox(width: 4),
          _chevron(),
        ],
      ),
    );
  }

  void _pickLanguage(
      BuildContext context, WidgetRef ref, AppLocalizations l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final current = ref.read(localeProvider)?.languageCode;
        Widget option(String code, String name) {
          final selected = current == code;
          return ListTile(
            title: Text(name,
                style: AppText.body.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
            trailing: selected
                ? const Icon(Icons.check_circle, color: AppColors.primary)
                : null,
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(Locale(code));
              Navigator.pop(sheetCtx);
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.chooseLanguage,
                      style: AppText.h2.copyWith(fontSize: 16, color: Colors.white)),
                ),
              ),
              option('en', l.languageEnglish),
              option('fr', l.languageFrench),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Icône associée à chaque document légal (par slug).
  IconData _legalIcon(String slug) {
    switch (slug) {
      case 'terms':
        return Icons.description_outlined;
      case 'privacy':
        return Icons.privacy_tip_outlined;
      case 'community':
        return Icons.groups_outlined;
      case 'cookie':
        return Icons.cookie_outlined;
      case 'copyright':
        return Icons.copyright;
      case 'refund':
        return Icons.receipt_long_outlined;
      case 'payments':
        return Icons.payments_outlined;
      case 'fraud-prevention':
        return Icons.gpp_maybe_outlined;
      case 'safety':
        return Icons.shield_outlined;
      case 'organizer':
        return Icons.verified_user_outlined;
      case 'data-retention':
        return Icons.storage_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  /// Liste embarquée utilisée si la DB est indisponible (hors-ligne).
  List<Widget> _fallbackLegalTiles(BuildContext context) => [
        _legal(context, Icons.description_outlined, 'Terms of Service', 'terms'),
        _legal(context, Icons.privacy_tip_outlined, 'Privacy Policy', 'privacy'),
        _legal(context, Icons.groups_outlined, 'Community Guidelines',
            'community'),
        _legal(context, Icons.cookie_outlined, 'Cookie Policy', 'cookie'),
        _legal(context, Icons.copyright, 'Copyright Policy', 'copyright'),
        _legal(context, Icons.receipt_long_outlined, 'Refund Policy', 'refund'),
        _legal(context, Icons.shield_outlined, 'Safety Policy', 'safety'),
        _legal(context, Icons.verified_user_outlined, 'Organizer Standards',
            'organizer'),
      ];

  Widget _staticTile(IconData icon, String label, String value) => _row(
        icon,
        label,
        onTap: null,
        trailing: Text(
          value,
          style: AppText.bodySm.copyWith(color: AppColors.textLow),
        ),
      );

  Widget _danger(BuildContext context, IconData icon, String label,
          {required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.error.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.error, size: 18),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppText.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.error),
              ),
            ],
          ),
        ),
      );

  Widget _row(IconData icon, String label,
      {required VoidCallback? onTap, Widget? trailing, bool dimmed = false}) {
    final opacity = dimmed ? 0.4 : 0.85;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(opacity), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(color: Colors.white.withOpacity(dimmed ? 0.55 : 1)),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _chevron() => Icon(Icons.chevron_right,
      color: AppColors.textLow, size: 18);
}
