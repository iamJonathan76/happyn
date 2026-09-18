import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/people_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/person_row.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Abonnes et abonnements d'une personne, en deux onglets.
///
/// Les compteurs du profil annoncaient « 12 abonnes » sans qu'on puisse
/// savoir qui. Un chiffre qu'on ne peut pas ouvrir donne l'impression d'une
/// app inachevee.
class FollowListScreen extends StatelessWidget {
  final String userId;
  final String title;
  final FollowListKind initial;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.title,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      initialIndex: initial == FollowListKind.followers ? 0 : 1,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.h3),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textLow,
            labelStyle: AppText.smallBold,
            dividerColor: Colors.white.withOpacity(0.06),
            tabs: [Tab(text: l.followers), Tab(text: l.following)],
          ),
        ),
        body: TabBarView(
          children: [
            _FollowList(userId: userId, kind: FollowListKind.followers),
            _FollowList(userId: userId, kind: FollowListKind.following),
          ],
        ),
      ),
    );
  }
}

class _FollowList extends ConsumerWidget {
  final String userId;
  final FollowListKind kind;
  const _FollowList({required this.userId, required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final key = (userId, kind);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async {
        ref.invalidate(followListProvider(key));
        await ref.read(followListProvider(key).future);
      },
      child: ref.watch(followListProvider(key)).when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
            // On distingue l'echec du vide : « personne » et « impossible de
            // charger » ne demandent pas la meme reaction.
            error: (_, _) => _message(l.followListFailed),
            data: (people) => people.isEmpty
                ? _message(kind == FollowListKind.followers
                    ? l.noFollowersYet
                    : l.noFollowingYet)
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                    itemCount: people.length,
                    itemBuilder: (_, i) => PersonRow(person: people[i]),
                  ),
          ),
    );
  }

  /// Defilable, pour que le geste de rafraichissement reste possible.
  Widget _message(String text) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 120),
        children: [
          Icon(Icons.people_outline, size: 44, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(color: AppColors.textLow)),
        ],
      );
}
