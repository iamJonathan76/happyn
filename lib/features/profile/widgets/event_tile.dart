import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:happyn/core/events/event_utils.dart';
import 'package:happyn/features/events/event_detail_screen.dart';

class EventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onDelete;

  const EventTile({required this.event, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (event['image_url'] ?? '') as String;
    final date = event['start_date'] != null
        ? DateTime.parse(event['start_date']).toString().substring(0, 10)
        : 'TBD';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  Container(color: AppColors.card),
              errorWidget: (_, _, _) => Container(
                color: AppColors.card,
                child: const Icon(Icons.event, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'] as String,
                  style: AppText.h5.copyWith(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        event['category'] as String,
                        style: AppText.microBold.copyWith(color: AppColors.lavender),
                      ),
                    ),
                    Text(
                      date,
                      style: AppText.micro,
                    ),
                    ...(() {
                      final st = eventStatus(event);
                      final (label, color) = st == 'cancelled'
                          ? (AppLocalizations.of(context).statusCancelled,
                              AppColors.error)
                          : st == 'draft'
                              ? (AppLocalizations.of(context).statusUnpublished,
                                  AppColors.amber)
                              : isEventPast(event)
                                  ? (AppLocalizations.of(context).statusEnded,
                                      AppColors.textMed)
                                  : (null, Colors.white);
                      if (label == null) return <Widget>[];
                      return [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: AppText.microBold.copyWith(color: color),
                          ),
                        ),
                      ];
                    })(),
                  ],
                ),
              ],
            ),
          ),

          // Delete
          GestureDetector(
            onTap: () => _confirmDelete(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: AppColors.error,
                size: 16,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.of(context).deleteEventTitle,
          style: AppText.h4.copyWith(color: Colors.white),
        ),
        content: Text(
          AppLocalizations.of(context).deleteEventBody,
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel,
                style: AppText.body),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: Text(AppLocalizations.of(context).delete,
                style: AppText.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
