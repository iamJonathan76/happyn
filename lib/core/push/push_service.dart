import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Clé du navigateur racine, posée sur le `MaterialApp`. Elle permet d'ouvrir
/// un écran depuis l'extérieur de l'arbre de widgets — ici, au toucher d'une
/// bannière de notification, où l'on n'a aucun `BuildContext` sous la main.
final navigatorKey = GlobalKey<NavigatorState>();

/// Notifications poussées.
///
/// La table `notifications` se remplissait déjà, mais personne n'était prévenu
/// quand l'app était fermée — or c'est exactement là que ça compte. Apprendre
/// l'annulation d'un événement en ouvrant l'app par hasard, c'est l'apprendre
/// trop tard.
///
/// L'envoi n'est PAS déclenché par l'app : un webhook sur `notifications` appelle
/// la fonction Edge `send-push`. Tout nouveau type de notification est donc
/// poussé sans une ligne de code supplémentaire ici.
///
/// iOS n'est pas couvert : les notifications Apple passent par APNs, qui exige
/// le compte développeur payant. Le code ci-dessous ne fera simplement rien sur
/// iPhone tant que ce ne sera pas le cas.
class PushService {
  static bool _ready = false;

  /// Routage du toucher d'une notification, injecté par la couche `features`
  /// au démarrage. On passe par un hook pour que `core` n'importe pas les
  /// écrans de `features` : ici on ne fait que transporter le message, c'est
  /// `push_router.dart` qui sait quel écran ouvrir.
  static void Function(RemoteMessage message)? onNotificationTap;

  /// Le message qui a ouvert l'app alors qu'elle était FERMÉE. On ne peut pas
  /// naviguer tout de suite : la session n'est pas encore restaurée et le
  /// navigateur n'existe pas. On le garde ; `MainShell` le consomme une fois
  /// arrivé à l'accueil, quand tout est prêt.
  static RemoteMessage? _pendingInitial;

  /// Vrai quand Firebase a démarré. Sans `google-services.json` (absent du
  /// dépôt), l'initialisation échoue — et l'app doit continuer normalement :
  /// ne pas recevoir de notification est un désagrément, ne pas démarrer est
  /// une panne.
  static bool get isAvailable => _ready;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      debugPrint('PushService: Firebase indisponible ($e)');
      return;
    }

    // Le jeton change tout seul (réinstallation, restauration de sauvegarde,
    // rotation par Google). Sans cette écoute, les notifications cesseraient
    // d'arriver un jour sans que rien ne le signale.
    FirebaseMessaging.instance.onTokenRefresh.listen(_save);

    // Afficher la bannière MÊME quand l'app est au premier plan. iOS la masque
    // par défaut : sans ça, un message reçu pendant qu'on navigue n'apparaît
    // nulle part sur le moment. (Sans effet sur Android, qui l'affiche déjà.)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Toucher une bannière alors que l'app est en ARRIÈRE-PLAN : on route tout
    // de suite, le navigateur est prêt.
    FirebaseMessaging.onMessageOpenedApp.listen(_dispatch);

    // App FERMÉE : on retient le message, sans naviguer encore (voir plus bas).
    _pendingInitial = await FirebaseMessaging.instance.getInitialMessage();
  }

  static void _dispatch(RemoteMessage message) => onNotificationTap?.call(message);

  /// À appeler une fois l'accueil atteint (session restaurée, navigateur prêt) :
  /// ouvre l'écran de la notification qui a lancé l'app depuis l'état fermé.
  static void consumePendingTap() {
    final msg = _pendingInitial;
    if (msg == null) return;
    _pendingInitial = null;
    onNotificationTap?.call(msg);
  }

  /// Demande l'autorisation et enregistre le jeton de cet appareil.
  ///
  /// Appelé après la connexion, pas au premier lancement : demander la
  /// permission avant que la personne sache ce qu'est l'app fait refuser la
  /// majorité des gens, et un refus Android est définitif jusqu'aux réglages
  /// système.
  static Future<void> registerForUser() async {
    if (!_ready) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _save(token);
    } catch (e) {
      debugPrint('PushService.registerForUser: $e');
    }
  }

  static Future<void> _save(String token) async {
    // Inutile d'enregistrer un jeton sans compte connecté : le serveur
    // l'attacherait à personne (auth.uid() nul) et refuserait.
    if (Supabase.instance.client.auth.currentUser == null) return;
    try {
      // Passe par la fonction serveur plutôt qu'un upsert direct. Si cet
      // appareil servait déjà à un autre compte, sa ligne lui appartient
      // encore : l'upsert ne pouvait pas l'écraser (la policy UPDATE refuse la
      // ligne d'autrui) et la suppression est désormais limitée à ses propres
      // lignes. `register_device_token` retire la ligne de l'ancien compte puis
      // pose la nôtre, de façon atomique et côté serveur — le seul endroit
      // habilité à toucher la ligne d'un autre. Voir la migration
      // 20261020000000_device_tokens_delete_own.
      await Supabase.instance.client.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (e) {
      debugPrint('PushService._save: $e');
    }
  }

  /// À appeler AVANT de se déconnecter.
  ///
  /// Sans ça, la ligne resterait attachée au compte précédent : la personne
  /// suivante à se connecter sur ce téléphone recevrait les notifications de
  /// quelqu'un d'autre. C'est une fuite de données, pas un détail de confort.
  static Future<void> unregister() async {
    if (!_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('token', token);
    } catch (e) {
      debugPrint('PushService.unregister: $e');
    }
  }
}
