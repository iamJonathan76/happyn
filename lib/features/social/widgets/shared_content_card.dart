import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/features/events/event_detail_screen.dart';
import 'package:happyn/features/social/post_view_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lu avec les droits de la personne qui REGARDE, pas de celle qui a envoyé :
/// une publication réservée aux participants revient vide chez qui n'y a pas
/// accès, et la carte le dit au lieu de la montrer.
final _sharedPostProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, id) async {
      return await Supabase.instance.client
          .from('feed_posts')
          .select()
          .eq('id', id)
          .maybeSingle();
    });

final _sharedEventProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, id) async {
      return await Supabase.instance.client
          .from('events')
          .select()
          .eq('id', id)
          .maybeSingle();
    });

/// La carte d'une publication ou d'un événement partagé dans une conversation.
class SharedContentCard extends ConsumerWidget {
  final String kind; // 'post' | 'event'
  final String? contentId; // null : le contenu a été supprimé depuis

  const SharedContentCard({super.key, required this.kind, this.contentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final id = contentId;
    if (id == null) return _notice(l.sharedContentDeleted);

    final row = kind == 'post'
        ? ref.watch(_sharedPostProvider(id))
        : ref.watch(_sharedEventProvider(id));

    return row.when(
      loading: () => const SizedBox(
        height: 64,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      error: (_, _) => _notice(l.sharedContentUnavailable),
      data: (data) {
        if (data == null) return _notice(l.sharedContentUnavailable);
        final isPost = kind == 'post';
        // Une publication sans photo prend l'affiche de son événement.
        final own = (data['image_url'] as String?) ?? '';
        final image = own.isNotEmpty
            ? own
            : (data['event_image'] as String? ?? '');
        final title = isPost
            ? (((data['caption'] as String?) ?? '').trim().isNotEmpty
                  ? (data['caption'] as String).trim()
                  : (data['event_title'] as String? ?? ''))
            : (data['title'] as String? ?? '');
        final subtitle = isPost
            ? (data['author_name'] as String? ?? '')
            : AppDates.dowDayMonthYear(context, data['start_date'] as String?);

        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => isPost
                  ? PostViewScreen(post: data)
                  : EventDetailScreen(event: data),
            ),
          ),
          child: Container(
            width: 230,
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (image.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          Container(color: AppColors.imagePlaceholder),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.smallBold.copyWith(color: Colors.white),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.micro.copyWith(
                            color: AppColors.textLow,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _notice(String text) => Container(
    width: 230,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.cardDark,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      text,
      style: AppText.caption.copyWith(color: AppColors.textLow),
    ),
  );
}
