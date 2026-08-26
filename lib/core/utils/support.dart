import 'package:url_launcher/url_launcher.dart';

/// Adresse de contact de HAPPYN.
///
/// Une seule source pour l'app ; le site a la sienne dans `web/assets/js/
/// config.js`. Les deux doivent rester identiques : un utilisateur qui écrit
/// depuis le site et un autre depuis l'app doivent arriver au même endroit.
///
/// Le nom de marque reste HAPPYN : le domaine n'est qu'une adresse qu'on
/// clique. `happyn.com` etait pris et `happyn.ca` exige une presence canadienne
/// que seule l'entreprise, une fois enregistree, permettra d'invoquer — d'ou
/// `happynevents.com` en attendant. Ne jamais mettre ici une adresse qui
/// n'existe pas : un lien de contact mort est pire que pas de lien.
const String kSupportEmail = 'contact@happynevents.com';

/// Ouvre l'app de courriel sur un message pré-rempli à destination du support.
///
/// [context] décrit d'où vient la demande (« Ticket », « Compte »…) et finit
/// dans l'objet : sans ça, tous les messages arrivent sous le même titre et il
/// devient impossible de trier ce qui est urgent.
///
/// Renvoie `false` si aucune app de courriel n'est configurée — l'appelant doit
/// alors afficher l'adresse en clair, sinon l'utilisateur reste coincé sans
/// savoir comment joindre qui que ce soit.
Future<bool> contactSupport({String? subject, String? body}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: kSupportEmail,
    query: [
      if (subject != null) 'subject=${Uri.encodeComponent(subject)}',
      if (body != null) 'body=${Uri.encodeComponent(body)}',
    ].join('&'),
  );
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Page web ou atterrit le lien de reinitialisation du mot de passe.
///
/// Doit etre declaree a l'identique dans Supabase (Authentication > URL
/// Configuration > Redirect URLs). Sans cette declaration Supabase refuse la
/// redirection : c'est ce qui empeche quelqu'un de faire pointer le lien vers
/// son propre site pour recuperer la session de la personne qui clique.
const String kPasswordResetUrl = 'https://happynevents.com/reset.html';
