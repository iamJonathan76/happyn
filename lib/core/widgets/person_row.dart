import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/auth_provider.dart';
import 'package:happyn/core/providers/people_provider.dart';
import 'package:happyn/core/providers/social_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/features/profile/profile_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Une personne dans une liste : recherche, abonnes, abonnements.
///
/// Une seule ligne pour les trois ecrans : si elle differait de l'un a
/// l'autre, la meme personne aurait trois visages selon l'endroit ou on la
/// croise.
class PersonRow extends ConsumerStatefulWidget {
  final PersonSummary person;
  const PersonRow({super.key, required this.person});

  @override
  ConsumerState<PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends ConsumerState<PersonRow> {
  bool _busy = false;

  Future<void> _toggle(bool isFollowing) async {
    setState(() => _busy = true);
    try {
      isFollowing
          ? await unfollowUser(widget.person.id)
          : await followUser(widget.person.id);
      ref.invalidate(followingProvider);
      ref.invalidate(publicProfileProvider(widget.person.id));
    } catch (_) {
      // Le bouton reprend son etat d'origine au rafraichissement : l'echec se
      // voit sans message supplementaire.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = widget.person;
    final me = ref.watch(currentUserIdProvider);
    final following =
        ref.watch(followingProvider).asData?.value ?? const <String>{};
    final isFollowing = following.contains(p.id);
    final isMe = p.id == me;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: p.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _Avatar(url: p.avatarUrl, name: p.displayName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  if (p.username.isNotEmpty && p.fullName.isNotEmpty)
                    Text('@${p.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.small),
                ],
              ),
            ),
            // On ne se suit pas soi-meme : la base le refuserait
            // (`no_self_follow`), autant ne pas proposer le bouton.
            if (!isMe) ...[
              const SizedBox(width: 10),
              _FollowChip(
                following: isFollowing,
                busy: _busy,
                // `unfollow` porte deja le libelle d'etat « Abonne », comme sur le profil.
                label: isFollowing ? l.unfollow : l.follow,
                onTap: () => _toggle(isFollowing),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FollowChip extends StatelessWidget {
  final bool following;
  final bool busy;
  final String label;
  final VoidCallback onTap;

  const _FollowChip({
    required this.following,
    required this.busy,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // Plein pour « Suivre », en creux pour « Abonne » : l'action
          // disponible attire l'oeil, l'etat acquis s'efface.
          gradient: following
              ? null
              : const LinearGradient(
                  colors: [AppColors.primary, AppColors.pink]),
          color: following ? Colors.white.withOpacity(0.06) : null,
          borderRadius: BorderRadius.circular(10),
          border: following
              ? Border.all(color: Colors.white.withOpacity(0.14))
              : null,
        ),
        child: busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: AppText.smallBold.copyWith(color: Colors.white)),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final clean = name.replaceFirst('@', '');
    final initial = clean.isEmpty ? '?' : clean[0].toUpperCase();
    final fallback = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      color: AppColors.primary.withOpacity(0.22),
      child: Text(initial,
          style: AppText.bodySm.copyWith(
              color: AppColors.lavenderLight, fontWeight: FontWeight.w700)),
    );
    final u = url ?? '';
    return ClipOval(
      child: u.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: u,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}
