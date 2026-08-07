import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/events_provider.dart';
import 'package:happyn/core/providers/moderation_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Liste des comptes bloqués, avec possibilité de débloquer.
///
/// Note : la RLS de `profiles` ne permet de lire que son propre profil, donc on
/// ne peut pas afficher le nom du compte bloqué — seulement un libellé
/// générique. Le déblocage fonctionne indépendamment.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final blockedAsync = ref.watch(blockedUsersProvider);

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
        error: (e, _) => Center(
          child: Text(l.couldNotLoadEvents,
              style: AppText.body.copyWith(color: AppColors.textLow)),
        ),
        data: (blocked) {
          if (blocked.isEmpty) return _empty(l);
          final ids = blocked.toList();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            itemCount: ids.length,
            itemBuilder: (context, i) => _row(context, ref, l, ids[i]),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, AppLocalizations l,
      String userId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.block, color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.blockedAccount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySm.copyWith(color: Colors.white)),
                Text(userId.substring(0, 8).toUpperCase(),
                    style: AppText.micro),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              await unblockUser(userId);
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
