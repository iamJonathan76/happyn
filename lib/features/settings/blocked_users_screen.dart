import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/providers/moderation_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Liste des comptes bloqués (nom + avatar), avec déblocage.
///
/// Les détails viennent de la fonction `blocked_users_details()`, en
/// SECURITY DEFINER : elle ne renvoie que le nom et l'avatar des comptes que
/// l'appelant a lui-même bloqués. On évite ainsi d'ouvrir la RLS de `profiles`,
/// qui aurait exposé l'email et la date de naissance au passage.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final blockedAsync = ref.watch(blockedUsersDetailsProvider);

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
        title: Text(l.blockedUsers, style: AppText.h2),
      ),
      body: blockedAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) {
          debugPrint('blockedUsersDetailsProvider error: $e');
          return Center(
            child: Text(l.couldNotLoadEvents,
                style: AppText.body.copyWith(color: AppColors.textLow)),
          );
        },
        data: (users) {
          if (users.isEmpty) return _empty(l);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            itemCount: users.length,
            itemBuilder: (context, i) => _row(context, ref, l, users[i]),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, AppLocalizations l,
      Map<String, dynamic> user) {
    final id = user['id'] as String;
    final name = (user['full_name'] as String?)?.trim();
    final avatarUrl = (user['avatar_url'] as String?) ?? '';
    // Un compte peut ne pas avoir renseigné son nom.
    final label = (name == null || name.isEmpty) ? l.blockedAccount : name;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          _avatar(avatarUrl, label),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySm.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              await unblockUser(id);
              ref.invalidate(blockedUsersProvider);
              ref.invalidate(eventsProvider); // ses events réapparaissent
              if (context.mounted) showAppSnack(context, l.userUnblocked);
            },
            child: Text(l.unblock,
                style: AppText.smallBold.copyWith(color: AppColors.lavender)),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String url, String label) {
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
    final fallback = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      color: AppColors.primary.withOpacity(0.18),
      child: Text(initial,
          style: AppText.h4.copyWith(color: AppColors.lavenderLight)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }

  Widget _empty(AppLocalizations l) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 48, color: AppColors.textFaint),
              const SizedBox(height: 14),
              Text(l.blockedUsersEmpty,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.textLow)),
              const SizedBox(height: 8),
              Text(l.blockedUsersEmptyBody,
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: AppColors.textFaint)),
            ],
          ),
        ),
      );
}
