import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/attendees_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/features/profile/profile_screen.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Liste des participants, réservée à l'organisateur de l'événement.
///
/// L'organisateur voyait un nombre de billets vendus sans savoir qui vient.
/// Cet écran répond à deux moments distincts : avant l'événement, préparer ;
/// à la porte, retrouver quelqu'un et voir qui manque encore.
///
/// La recherche est purement locale. Une liste de porte se consulte souvent
/// avec une connexion mauvaise — refaire un aller-retour serveur à chaque
/// lettre rendrait l'écran inutilisable là où il sert le plus.
class AttendeesScreen extends ConsumerStatefulWidget {
  final String eventId;
  const AttendeesScreen({super.key, required this.eventId});

  @override
  ConsumerState<AttendeesScreen> createState() => _AttendeesScreenState();
}

class _AttendeesScreenState extends ConsumerState<AttendeesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(eventAttendeesProvider(widget.eventId));

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
        title: Text(l.attendeesTitle,
            style: AppText.h2.copyWith(color: Colors.white)),
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, _) => _message(l.attendeesError),
        data: (people) => _list(l, people),
      ),
    );
  }

  Widget _list(AppLocalizations l, List<EventAttendee> people) {
    if (people.isEmpty) return _message(l.attendeesEmpty);

    final needle = _query.trim().toLowerCase();
    final shown = needle.isEmpty
        ? people
        : people
            .where((a) => (a.fullName ?? '').toLowerCase().contains(needle))
            .toList();

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: () async =>
          ref.invalidate(eventAttendeesProvider(widget.eventId)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _summary(l, people),
          const SizedBox(height: 16),
          // La recherche n'apparaît qu'au-delà de quelques personnes : sur une
          // liste courte elle ne sert à rien et mange la place de la liste.
          if (people.length > 8) ...[
            _search(l),
            const SizedBox(height: 12),
          ],
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(l.attendeesNoMatch,
                  textAlign: TextAlign.center, style: AppText.body),
            )
          else
            for (final person in shown) _row(l, person),
        ],
      ),
    );
  }

  /// Trois compteurs, libellé au-dessous du nombre.
  ///
  /// Les libellés sont invariables et les nombres au-dessus : pas de « 1
  /// personnes » à gérer dans deux langues.
  Widget _summary(AppLocalizations l, List<EventAttendee> people) {
    var tickets = 0;
    var scanned = 0;
    for (final a in people) {
      tickets += a.ticketCount;
      scanned += a.scannedCount;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _stat(l.attendeesPeople, people.length),
          _stat(l.attendeesTickets, tickets),
          _stat(l.attendeesCheckedIn, scanned),
        ],
      ),
    );
  }

  Widget _stat(String label, int value) => Expanded(
        child: Column(
          children: [
            Text('$value',
                style: AppText.display
                    .copyWith(fontSize: 24, color: Colors.white)),
            const SizedBox(height: 2),
            Text(label, style: AppText.small, textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _search(AppLocalizations l) => TextField(
        onChanged: (v) => setState(() => _query = v),
        style: AppText.bodySm.copyWith(color: Colors.white),
        decoration: InputDecoration(
          hintText: l.attendeesSearchHint,
          hintStyle: AppText.bodySm.copyWith(color: AppColors.textLow),
          prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textLow),
          filled: true,
          fillColor: AppColors.cardDark,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      );

  Widget _row(AppLocalizations l, EventAttendee person) {
    final name = (person.fullName?.isNotEmpty ?? false)
        ? person.fullName!
        : l.attendeeNoName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: _avatar(person),
        title: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySm.copyWith(color: Colors.white)),
        // Le sous-titre ne parle que quand il a quelque chose à dire : une
        // arrivée partielle est le seul cas ambigu à la porte.
        subtitle: person.partlyScanned
            ? Text(
                l.attendeesScannedOf(person.scannedCount, person.ticketCount),
                style: AppText.micro.copyWith(color: AppColors.amber))
            : null,
        trailing: _trailing(person),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: person.id))),
      ),
    );
  }

  /// À droite : le nombre de places quand il y en a plusieurs, et une coche
  /// quand tout le monde est entré.
  ///
  /// Rien n'est affiché pour une personne seule non scannée — le cas ordinaire
  /// n'a pas besoin d'être décoré, et ce silence fait ressortir les autres.
  Widget _trailing(EventAttendee person) {
    final badges = <Widget>[
      if (person.ticketCount > 1)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('x${person.ticketCount}',
              style:
                  AppText.microBold.copyWith(color: AppColors.lavenderLight)),
        ),
      if (person.allScanned)
        Icon(Icons.check_circle, size: 18, color: AppColors.green),
    ];

    if (badges.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < badges.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          badges[i],
        ],
      ],
    );
  }

  Widget _avatar(EventAttendee person, {double size = 40}) {
    final name = person.fullName ?? '';
    final url = person.avatarUrl ?? '';
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

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: AppText.body),
        ),
      );
}
