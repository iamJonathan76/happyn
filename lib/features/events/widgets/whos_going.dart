import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/attendance_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/features/profile/profile_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Section « Qui y va » sur la fiche d'un événement.
///
/// N'affiche que des connexions mutuelles ayant explicitement rendu leur
/// présence visible. Si personne ne correspond, la section disparaît
/// entièrement — mieux vaut ne rien montrer qu'annoncer « 0 personne », qui
/// laisserait deviner qu'il y a quelque chose à voir.
class WhosGoing extends ConsumerWidget {
  final String eventId;
  const WhosGoing({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final people = ref.watch(whoIsGoingProvider(eventId)).asData?.value;
    if (people == null || people.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _openList(context, people, l),
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            _avatarStack(people),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.whosGoing,
                      style: AppText.captionBold.copyWith(color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    l.connectionsGoing(people.length),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.small,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textLow),
          ],
        ),
      ),
    );
  }

  /// Avatars superposés, 3 au maximum.
  Widget _avatarStack(List<Map<String, dynamic>> people) {
    final shown = people.take(3).toList();
    return SizedBox(
      width: 30.0 + (shown.length - 1) * 20,
      height: 34,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cardDark,
                ),
                child: _avatar(shown[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> person, {double size = 30}) {
    final name = (person['full_name'] as String?)?.trim() ?? '';
    final url = (person['avatar_url'] as String?) ?? '';
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppColors.primary.withOpacity(0.25),
      child: Text(initial,
          style: AppText.micro.copyWith(
              fontWeight: FontWeight.w800, color: AppColors.lavenderLight)),
    );
    return ClipOval(
      child: url.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }

  void _openList(BuildContext context, List<Map<String, dynamic>> people,
      AppLocalizations l) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 18),
            Text(l.whosGoing, style: AppText.h3),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: people.length,
                itemBuilder: (context, i) {
                  final p = people[i];
                  final attended = p['status'] == 'attended';
                  return ListTile(
                    leading: _avatar(p, size: 40),
                    title: Text(
                      (p['full_name'] as String?)?.trim().isNotEmpty == true
                          ? p['full_name'] as String
                          : l.blockedAccount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(color: Colors.white),
                    ),
                    subtitle: attended
                        ? Text(l.attendedLabel, style: AppText.micro)
                        : null,
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              ProfileScreen(userId: p['id'] as String)));
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
