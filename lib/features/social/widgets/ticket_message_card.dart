import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/dates.dart';
import 'package:happyn/features/ticketing/qr_ticket_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Le billet tel que le DESTINATAIRE le voit, avec son type et son événement.
///
/// Lu avec ses droits : seul le détenteur actuel lit un billet. Chez
/// l'expéditeur — ou si le destinataire l'a lui-même transféré ou annulé
/// depuis — la réponse est vide, et la carte n'offre pas de bouton qui
/// mènerait à un billet qu'on n'a plus.
final _ownTicketProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, ticketId) async {
  return await Supabase.instance.client
      .from('tickets')
      .select('*, events(*), ticket_types(*)')
      .eq('id', ticketId)
      .maybeSingle();
});

final _eventProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, eventId) async {
  return await Supabase.instance.client
      .from('events')
      .select()
      .eq('id', eventId)
      .maybeSingle();
});

/// Le message déposé dans la conversation par un transfert de billet.
///
/// Créé par le serveur seul (`transfer_ticket_to_user`) : l'app ne peut pas
/// en fabriquer un faux. Le mot de l'expéditeur, s'il y en a un, est dans la
/// carte et pas dans une bulle à part — il accompagne le billet.
class TicketMessageCard extends ConsumerWidget {
  const TicketMessageCard({
    super.key,
    required this.isMine,
    required this.otherName,
    required this.eventId,
    required this.ticketId,
    required this.note,
  });

  final bool isMine;

  /// L'autre personne de la conversation : l'expéditeur si on reçoit, le
  /// destinataire si on envoie.
  final String otherName;
  final String? eventId;
  final String? ticketId;
  final String note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ticket = (!isMine && ticketId != null)
        ? ref.watch(_ownTicketProvider(ticketId!)).asData?.value
        : null;
    final event = (ticket?['events'] as Map<String, dynamic>?) ??
        (eventId == null ? null : ref.watch(_eventProvider(eventId!)).asData?.value);
    final type = ticket?['ticket_types'] as Map<String, dynamic>?;

    final image = (event?['image_url'] as String?) ?? '';
    final date = AppDates.dowDayMonthYear(context, event?['start_date'] as String?);
    final city = ((event?['city'] as String?) ?? '').trim();

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isMine ? AppColors.messageMine.withValues(alpha: 0.35) : AppColors.sheet,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMine
              ? AppColors.lavenderLight.withValues(alpha: 0.25)
              : AppColors.pink.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isMine ? null : AppColors.brandGradient,
                  color: isMine ? Colors.white.withValues(alpha: 0.1) : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(FontAwesomeIcons.gift.data,
                    size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isMine
                      ? l.ticketMsgSent(otherName)
                      : l.ticketMsgReceived(otherName),
                  style: AppText.smallBold.copyWith(color: Colors.white, height: 1.3),
                ),
              ),
            ],
          ),
          if (event != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: image.isEmpty
                        ? Container(color: AppColors.imagePlaceholder)
                        : CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                Container(color: AppColors.imagePlaceholder),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((event['title'] ?? '') as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.smallBold.copyWith(color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(
                        [date, city].where((v) => v.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.micro.copyWith(color: AppColors.textMed),
                      ),
                      if (type != null) ...[
                        const SizedBox(height: 2),
                        Text((type['name'] ?? '') as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.micro
                                .copyWith(color: AppColors.lavenderLight)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('« $note »',
                style: AppText.bodySm.copyWith(
                    color: Colors.white, fontStyle: FontStyle.italic, height: 1.4)),
          ],
          // Le bouton seulement si on détient encore ce billet.
          if (ticket != null && event != null && type != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => QrTicketScreen(
                  ticket: ticket,
                  event: event,
                  ticketType: type,
                ),
              )),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.action,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(l.ticketMsgOpen,
                    style: AppText.smallBold.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
