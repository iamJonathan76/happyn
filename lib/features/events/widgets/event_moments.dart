import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/social_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/features/social/widgets/post_card.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Section « Moments » sur la fiche d'un événement.
///
/// Une bande de vignettes plutôt que des cartes complètes : la fiche est déjà
/// longue, et sur cet écran chaque carte répéterait le titre de l'événement
/// qu'on est justement en train de consulter. La vignette donne la preuve
/// visuelle, la liste complète donne le détail.
///
/// Disparaît entièrement quand il n'y a rien : un événement à venir n'a par
/// définition aucun moment, et un bloc vide donnerait l'impression d'un défaut.
class EventMoments extends ConsumerWidget {
  final String eventId;
  const EventMoments({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final posts = ref.watch(eventPostsProvider(eventId)).asData?.value;
    if (posts == null || posts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              l.moments,
              style: AppText.h2.copyWith(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text('${posts.length}', style: AppText.smallBold),
            const Spacer(),
            GestureDetector(
              onTap: () => _openAll(context, l),
              behavior: HitTestBehavior.opaque,
              child: Text(
                l.seeAll,
                style: AppText.smallBold.copyWith(
                  color: AppColors.lavenderLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _thumb(context, l, posts, i),
          ),
        ),
      ],
    );
  }

  Widget _thumb(
    BuildContext context,
    AppLocalizations l,
    List<Map<String, dynamic>> posts,
    int index,
  ) {
    final url = (posts[index]['image_url'] as String?) ?? '';
    final placeholder = Container(
      width: 92,
      height: 116,
      color: AppColors.imagePlaceholder,
      alignment: Alignment.center,
      child: Icon(Icons.photo_outlined, size: 20, color: AppColors.textLow),
    );
    return GestureDetector(
      onTap: () => _openAll(context, l, initialIndex: index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: url.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url,
                width: 92,
                height: 116,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
    );
  }

  void _openAll(
    BuildContext context,
    AppLocalizations l, {
    int initialIndex = 0,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EventMomentsScreen(
          eventId: eventId,
          initialIndex: initialIndex,
          title: l.moments,
        ),
      ),
    );
  }
}

/// Liste complète des moments d'un événement, en cartes.
class _EventMomentsScreen extends ConsumerStatefulWidget {
  final String eventId;
  final int initialIndex;
  final String title;
  const _EventMomentsScreen({
    required this.eventId,
    required this.initialIndex,
    required this.title,
  });

  @override
  ConsumerState<_EventMomentsScreen> createState() =>
      _EventMomentsScreenState();
}

class _EventMomentsScreenState extends ConsumerState<_EventMomentsScreen> {
  late final ScrollController _controller = ScrollController(
    initialScrollOffset: widget.initialIndex * 480.0,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posts =
        ref.watch(eventPostsProvider(widget.eventId)).asData?.value ??
        const <Map<String, dynamic>>[];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(widget.title, style: AppText.h3),
      ),
      body: ListView.builder(
        controller: _controller,
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: posts.length,
        itemBuilder: (_, i) => PostCard(
          post: posts[i],
          onChanged: () => ref.invalidate(eventPostsProvider(widget.eventId)),
        ),
      ),
    );
  }
}
