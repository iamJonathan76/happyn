import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/features/settings/edit_profile_screen.dart';
import 'package:happyn/features/settings/legal_page_screen.dart';
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
      backgroundColor: const Color(0xFF08080F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF08080F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l.settingsTitle,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
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
          _soon(context, Icons.tune, l.preferences),
          _soon(context, Icons.notifications_outlined, l.notificationPreferences),
          _languageTile(context, ref, l),

          // ── Social ────────────────────────────────────────────────
          _section(l.sectionSocial),
          _soon(context, Icons.group_outlined, l.friends),
          _soon(context, Icons.person_add_alt, l.following),
          _soon(context, Icons.people_alt_outlined, l.followers),
          _soon(context, Icons.block, l.blockedUsers),

          // ── My Activity ───────────────────────────────────────────
          _section(l.sectionMyActivity),
          _soon(context, Icons.bookmark_border, l.savedEvents),
          _soon(context, Icons.history, l.eventHistory),
          _soon(context, Icons.star_border, l.favoriteOrganizers),

          // ── Organizer Tools ───────────────────────────────────────
          _section(l.sectionOrganizerTools),
          _soon(context, Icons.event_note_outlined, l.myEvents),
          _soon(context, Icons.how_to_reg_outlined, l.attendeeManagement),
          _soon(context, Icons.bar_chart, l.analytics),
          _soon(context, Icons.payments_outlined, l.payouts),

          // ── Support ───────────────────────────────────────────────
          _section(l.sectionSupport),
          _soon(context, Icons.help_outline, l.helpCenter),
          _soon(context, Icons.support_agent, l.contactSupport),
          _soon(context, Icons.flag_outlined, l.reportProblem),

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
    // Placeholder : la vraie suppression (PIPEDA, droit à l'effacement) sera
    // une Edge Function dédiée. Pour l'instant on oriente vers le support.
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1535),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Account',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'To permanently delete your account and data, please contact '
          'support@happyn.com. Self-service deletion is coming soon.',
          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK',
                style: GoogleFonts.inter(color: const Color(0xFFA78BFA))),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1535),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('HAPPYN',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          'Find the ones. Be the moment.\n\nDiscover, create, and attend events. '
          'Version $appVersion.',
          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: GoogleFonts.inter(color: const Color(0xFFA78BFA))),
          ),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).comingSoon(label),
            style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1535),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: const Color(0xFFA78BFA),
          ),
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
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.white.withOpacity(0.4))),
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
      backgroundColor: const Color(0xFF16122B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final current = ref.read(localeProvider)?.languageCode;
        Widget option(String code, String name) {
          final selected = current == code;
          return ListTile(
            title: Text(name,
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            trailing: selected
                ? const Icon(Icons.check_circle, color: Color(0xFF7C3AED))
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
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
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

  Widget _soon(BuildContext context, IconData icon, String label) => _row(
        icon,
        label,
        onTap: () => _comingSoon(context, label),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            AppLocalizations.of(context).soon,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ),
        dimmed: true,
      );

  Widget _staticTile(IconData icon, String label, String value) => _row(
        icon,
        label,
        onTap: null,
        trailing: Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withOpacity(0.4),
          ),
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
            color: const Color(0xFFFF4B4B).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFF4B4B).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFFF4B4B), size: 18),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF4B4B),
                ),
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
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withOpacity(dimmed ? 0.55 : 1),
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _chevron() => Icon(Icons.chevron_right,
      color: Colors.white.withOpacity(0.3), size: 18);
}
