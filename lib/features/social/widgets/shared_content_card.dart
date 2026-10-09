import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/core/utils/post_image.dart';
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
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => isPost
                  ? PostViewScreen(post: data)
                  : EventDetailScreen(event: data),
            ),
          ),
          child: Container(
            width: _width,
            decoration: BoxDecoration(
              color: AppColors.sheet,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: isPost ? _post(context, data) : _event(context, data),
          ),
        );
      },
    );
  }

  /// Largeur fixe : une carte qui suivrait la largeur de sa photo ferait une
  /// conversation en dents de scie.
  static const double _width = 240;

  /// Comme sur Instagram : l'auteur, la photo dans sa forme, puis l'auteur et
  /// la légende — et, propre à HAPPYN, l'événement auquel le moment
  /// appartient.
  Widget _post(BuildContext context, Map<String, dynamic> data) {
    final author = (data['author_name'] as String?)?.trim() ?? '';
    final avatar = (data['author_avatar'] as String?) ?? '';
    final caption = ((data['caption'] as String?) ?? '').trim();
    final own = (data['image_url'] as String?) ?? '';
    // Une publication sans photo prend l'affiche de son événement.
    final image = own.isNotEmpty ? own : (data['event_image'] as String? ?? '');
    final aspect = own.isNotEmpty
        ? displayAspect((data['image_aspect'] as num?)?.toDouble())
        : 16 / 10;
    final eventTitle = (data['event_title'] as String?) ?? '';
    final eventDate =
        AppDates.dayMonthYear(context, data['event_start_date'] as String?);

    final initial = author.isEmpty ? '?' : author[0].toUpperCase();
    final fallback = Container(
      color: AppColors.primary.withValues(alpha: 0.25),
      alignment: Alignment.center,
      child: Text(initial,
          style: AppText.microBold.copyWith(color: Colors.white)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: avatar.isEmpty
                      ? fallback
                      : CachedNetworkImage(
                          imageUrl: avatar,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => fallback,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.smallBold.copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
        if (image.isNotEmpty)
          AspectRatio(
            aspectRatio: aspect,
            child: CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) =>
                  Container(color: AppColors.imagePlaceholder),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (caption.isNotEmpty)
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '$author ',
                        style: AppText.smallBold.copyWith(color: Colors.white)),
                    TextSpan(
                        text: caption,
                        style: AppText.small.copyWith(color: AppColors.textMed)),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (eventTitle.isNotEmpty) ...[
                if (caption.isNotEmpty) const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined,
                          size: 14, color: AppColors.textMed),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [eventTitle, eventDate]
                              .where((v) => v.isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppText.micro.copyWith(color: AppColors.textMed),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _event(BuildContext context, Map<String, dynamic> data) {
    final image = (data['image_url'] as String?) ?? '';
    final date =
        AppDates.dowDayMonthYear(context, data['start_date'] as String?);
    final city = ((data['city'] as String?) ?? '').trim();
    return Column(
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
              Text((data['title'] ?? '') as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.smallBold.copyWith(color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                [date, city].where((v) => v.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.micro.copyWith(color: AppColors.textLow),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notice(String text) => Container(
    width: _width,
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
