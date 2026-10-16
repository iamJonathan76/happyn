import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Itinéraire vers un lieu, dans l'app de cartes que la personne utilise.
///
/// Android propose lui-même les apps installées quand on ouvre un lien `geo:`.
/// iOS ne connaît pas `geo:` : on y ouvrait Google Maps **dans le navigateur**,
/// même avec Plans, Google Maps ou Waze installés. Sur iPhone, on propose donc
/// les apps réellement présentes, comme le font les grandes apps.
///
/// Plans et Google Maps reçoivent l'adresse en texte : avec un point GPS, ils
/// affichent « 45.425219,-75.718190 » comme destination. Waze et Android
/// reçoivent le point, plus sûr, qu'ils présentent bien. Le point n'est fourni
/// qu'à qui a le droit de connaître l'adresse — sinon l'itinéraire vise
/// seulement la ville.
Future<void> openDirections(
  BuildContext context, {
  required String title,
  required String address,
  double? latitude,
  double? longitude,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final hasPoint = latitude != null && longitude != null;
  final point = hasPoint ? '$latitude,$longitude' : null;
  final q = Uri.encodeComponent(address.trim());
  if (!hasPoint && address.trim().isEmpty) return;

  Future<void> launchOrWarn(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.couldNotOpenMaps)));
  }

  final web = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${point ?? q}');

  if (!Platform.isIOS) {
    final geo = Uri.parse(hasPoint ? 'geo:$point?q=$point($q)' : 'geo:0,0?q=$q');
    await launchOrWarn(await canLaunchUrl(geo) ? geo : web);
    return;
  }

  // Plans est toujours là sur un iPhone ; les autres seulement s'ils sont
  // installés (schémas déclarés dans LSApplicationQueriesSchemes).
  final dest = address.trim().isNotEmpty ? q : point!;
  final options = <(String, IconData, Uri)>[
    (l.appleMaps, Icons.map_outlined, Uri.parse('maps://?daddr=$dest')),
  ];
  final google = Uri.parse('comgooglemaps://?daddr=$dest&directionsmode=driving');
  if (await canLaunchUrl(google)) {
    options.add(('Google Maps', Icons.place_outlined, google));
  }
  final waze = Uri.parse(hasPoint
      ? 'waze://?ll=$point&navigate=yes'
      : 'waze://?q=$q&navigate=yes');
  if (await canLaunchUrl(waze)) {
    options.add(('Waze', Icons.directions_car_outlined, waze));
  }
  if (options.length == 1) {
    await launchOrWarn(options.first.$3);
    return;
  }
  if (!context.mounted) return;

  // La feuille d'actions native d'iOS, celle de Plans ou de Mail : titre
  // gris, choix en bleu, « Annuler » à part. Une feuille maison y faisait
  // tache.
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetCtx) => CupertinoActionSheet(
      title: Text('${l.directionsTo} $title'),
      actions: [
        for (final (name, _, uri) in options)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetCtx).pop();
              launchOrWarn(uri);
            },
            child: Text(name),
          ),
        CupertinoActionSheetAction(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: address));
            Navigator.of(sheetCtx).pop();
            messenger.showSnackBar(SnackBar(content: Text(l.addressCopied)));
          },
          child: Text(l.copyAddress),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(sheetCtx).pop(),
        child: Text(l.cancel),
      ),
    ),
  );
}

