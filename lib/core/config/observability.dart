import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Rapport de plantage.
///
/// Pourquoi : en production, les gens ne signalent pas les plantages — ils
/// désinstallent. Sans cet outil on ne saurait jamais qu'une erreur silencieuse
/// casse le tunnel de paiement chez 5 % des téléphones. Ce projet a déjà produit
/// trois fois des erreurs avalées qui se déguisaient en écran vide.
///
/// Le DSN n'est PAS dans le dépôt. Il est passé au build :
///
///   flutter run   --dart-define=SENTRY_DSN=https://…
///   flutter build --dart-define=SENTRY_DSN=https://…
///
/// Sans DSN, l'app démarre normalement et n'envoie rien. C'est le cas voulu en
/// développement : la console suffit, et on évite de polluer le projet Sentry
/// avec des erreurs qu'on est en train de provoquer soi-même.
///
/// Note : le DSN Sentry est conçu pour vivre dans un client (il n'autorise que
/// l'envoi, pas la lecture). On le garde tout de même hors du dépôt pour ne pas
/// que n'importe qui puisse remplir le quota gratuit de bruit.
const String _dsn = String.fromEnvironment('SENTRY_DSN');

bool get crashReportingEnabled => _dsn.isNotEmpty;

/// Démarre l'app sous surveillance quand un DSN est fourni, telle quelle sinon.
Future<void> runWithObservability(Future<void> Function() start) async {
  if (!crashReportingEnabled) {
    await start();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = _dsn;

      // Loi 25 / minimisation : on ne joint ni adresse IP, ni courriel, ni
      // aucune donnée de l'utilisateur au rapport. Une trace d'appel suffit à
      // corriger un bug ; l'identité de la personne n'y ajoute rien.
      options.sendDefaultPii = false;

      // Une capture d'écran jointe au rapport embarquerait le contenu
      // affiché — donc potentiellement un billet, un QR, un nom. (La
      // hiérarchie des widgets est désactivée par défaut ; son option est
      // marquée expérimentale, on ne la touche pas.)
      options.attachScreenshot = false;

      options.environment = kReleaseMode ? 'production' : 'debug';

      // Échantillonnage des performances : 20 % suffit à voir une tendance et
      // garde le quota gratuit pour ce qui compte vraiment, les erreurs.
      options.tracesSampleRate = 0.2;
    },
    appRunner: start,
  );
}
