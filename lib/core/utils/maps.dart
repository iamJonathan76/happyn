import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
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

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(l.directionsTo, style: AppText.caption),
            const SizedBox(height: 2),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.h3),
            const SizedBox(height: 14),
            for (final (name, icon, uri) in options)
              _option(icon, name, () {
                Navigator.of(sheetCtx).pop();
                launchOrWarn(uri);
              }),
            const Divider(color: AppColors.border, height: 20),
            _option(Icons.copy_rounded, l.copyAddress, () {
              Clipboard.setData(ClipboardData(text: address));
              Navigator.of(sheetCtx).pop();
              messenger.showSnackBar(SnackBar(content: Text(l.addressCopied)));
            }),
          ],
        ),
      ),
    ),
  );
}

Widget _option(IconData icon, String label, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.lavenderLight, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: AppText.bodySm
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ),
  );
}
