import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/social_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/features/social/widgets/post_card.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Les moments d'une personne en fil complet, ouvert depuis la grille du
/// profil sur la publication touchée.
///
/// Le fil s'ouvre SUR elle, sans défilement animé : les publications plus
/// récentes sont posées au-dessus du point d'ancrage, les plus anciennes
/// en dessous. Défiler jusqu'à elle après coup obligerait à construire
/// toutes celles d'avant, et l'écran sauterait à l'ouverture.
class UserMomentsScreen extends ConsumerWidget {
  final String userId;
  final String initialPostId;

  const UserMomentsScreen({
    super.key,
    required this.userId,
    required this.initialPostId,
  });

  static const _anchor = ValueKey('moments-anchor');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // La même source que la grille : un j'aime donné ici s'y retrouve au
    // retour.
    final posts = ref.watch(userPostsProvider(userId)).asData?.value ??
        const <Map<String, dynamic>>[];
    final found = posts.indexWhere((p) => p['id'] == initialPostId);
    // Publication supprimée entre-temps : on ouvre en tête plutôt que vide.
    final start = found < 0 ? 0 : found;
    final before = posts.sublist(0, start).reversed.toList();
    final after = posts.sublist(start);
    final name =
        posts.isEmpty ? '' : ((posts.first['author_name'] as String?) ?? '');

    void refresh() => ref.invalidate(userPostsProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.profileTabPosts, style: AppText.h3),
            if (name.isNotEmpty)
              Text(name,
                  style: AppText.micro.copyWith(color: AppColors.textMed)),
          ],
        ),
      ),
      body: CustomScrollView(
        center: _anchor,
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => PostCard(
                  key: ValueKey(before[i]['id']),
                  post: before[i],
                  onChanged: refresh),
              childCount: before.length,
            ),
          ),
          SliverPadding(
            key: _anchor,
            padding: const EdgeInsets.only(bottom: 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => PostCard(
                    key: ValueKey(after[i]['id']),
                    post: after[i],
                    onChanged: refresh),
                childCount: after.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
