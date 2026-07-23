// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get sectionAccount => 'Compte';

  @override
  String get sectionSocial => 'Social';

  @override
  String get sectionMyActivity => 'Mon activité';

  @override
  String get sectionOrganizerTools => 'Outils organisateur';

  @override
  String get sectionSupport => 'Assistance';

  @override
  String get sectionLegal => 'Légal';

  @override
  String get sectionAbout => 'À propos';

  @override
  String get sectionAccountActions => 'Actions du compte';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get preferences => 'Préférences';

  @override
  String get notificationPreferences => 'Préférences de notifications';

  @override
  String get language => 'Langue';

  @override
  String get friends => 'Amis';

  @override
  String get following => 'Abonnements';

  @override
  String get followers => 'Abonnés';

  @override
  String get blockedUsers => 'Utilisateurs bloqués';

  @override
  String get savedEvents => 'Événements enregistrés';

  @override
  String get eventHistory => 'Historique des événements';

  @override
  String get favoriteOrganizers => 'Organisateurs favoris';

  @override
  String get myEvents => 'Mes événements';

  @override
  String get attendeeManagement => 'Gestion des participants';

  @override
  String get analytics => 'Statistiques';

  @override
  String get payouts => 'Versements';

  @override
  String get helpCenter => 'Centre d\'aide';

  @override
  String get contactSupport => 'Contacter le support';

  @override
  String get reportProblem => 'Signaler un problème';

  @override
  String get appVersion => 'Version de l\'app';

  @override
  String get aboutHappyn => 'À propos de HAPPYN';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get soon => 'Bientôt';

  @override
  String comingSoon(String label) {
    return '$label — bientôt disponible';
  }

  @override
  String get chooseLanguage => 'Choisir la langue';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get close => 'Fermer';

  @override
  String get ok => 'OK';

  @override
  String get logIn => 'Se connecter';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get welcomeBack => 'Bon retour 👋';

  @override
  String get joinExperience => 'Rejoins l\'expérience 🎉';

  @override
  String get fullName => 'Nom complet';

  @override
  String get emailAddress => 'Adresse e-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get dateOfBirth => 'Date de naissance';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get orEmail => 'ou par e-mail';

  @override
  String get appleSignInSoon => 'Connexion Apple bientôt disponible';

  @override
  String get passwordResetSoon =>
      'Réinitialisation du mot de passe — bientôt disponible';

  @override
  String get bySigningUpAgree => 'En t\'inscrivant, tu acceptes nos ';

  @override
  String get termsWord => 'Conditions';

  @override
  String get andConnector => ' et notre ';

  @override
  String get privacyWord => 'Politique de confidentialité';

  @override
  String get errFillAllFields => 'Veuillez remplir tous les champs requis';

  @override
  String get errEnterName => 'Veuillez entrer votre nom';

  @override
  String get errEnterDob => 'Veuillez entrer votre date de naissance';

  @override
  String errMinAccountAge(int age) {
    return 'Vous devez avoir au moins $age ans pour utiliser HAPPYN';
  }

  @override
  String get accountCreatedCheckEmail =>
      'Compte créé. Vérifiez votre e-mail pour confirmer votre compte.';

  @override
  String get greetingMorning => 'Bonjour';

  @override
  String get greetingAfternoon => 'Bon après-midi';

  @override
  String get greetingEvening => 'Bonsoir';

  @override
  String get searchHint => 'Rechercher événements, artistes, lieux...';

  @override
  String eventsToDiscover(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements à découvrir',
      one: '1 événement à découvrir',
      zero: 'Aucun événement à découvrir',
    );
    return '$_temp0';
  }

  @override
  String get forYou => 'Pour toi';

  @override
  String get popularNearYou => 'Populaire près de toi';

  @override
  String get seeAll => 'Tout voir';

  @override
  String get couldNotLoadEvents => 'Impossible de charger les événements';

  @override
  String get noEventsYet =>
      'Aucun événement pour l\'instant — crée le premier ! 🎉';

  @override
  String get categoryAll => 'Tout';

  @override
  String get free => 'Gratuit';

  @override
  String get discoverTitle => 'Découvrir';

  @override
  String get haveACode => 'Un code ?';

  @override
  String get searchHintDiscover => 'Événements, lieux, artistes...';

  @override
  String get filterTonight => 'Ce soir';

  @override
  String eventsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements trouvés',
      one: '1 événement trouvé',
    );
    return '$_temp0';
  }

  @override
  String noResultsFor(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get noEventsInCategory =>
      'Aucun événement dans cette catégorie pour l\'instant';

  @override
  String get tryDifferentSearch =>
      'Essayez une autre recherche ou un autre filtre';

  @override
  String get actionFailed => 'Échec de l\'action. Veuillez réessayer.';

  @override
  String get publish => 'Publier';

  @override
  String get unpublish => 'Dépublier';

  @override
  String get cancelEvent => 'Annuler l\'événement';

  @override
  String get cancelEventTitle => 'Annuler cet événement ?';

  @override
  String get cancelEventBody =>
      'Les détenteurs de billets seront notifiés et l\'événement sera marqué comme annulé. C\'est irréversible.';

  @override
  String get keep => 'Conserver';

  @override
  String get eventCancelledMsg => 'Événement annulé';

  @override
  String get eventPublishedMsg => 'Événement publié';

  @override
  String get eventUnpublishedMsg => 'Événement dépublié';

  @override
  String get tbd => 'À définir';

  @override
  String get statusCancelled => 'Annulé';

  @override
  String get statusEnded => 'Terminé';

  @override
  String get ctaUnavailable => 'Indisponible';

  @override
  String get eventEnded => 'Événement terminé';

  @override
  String get sharingSoon => 'Partage — bientôt disponible';

  @override
  String get aboutThisEvent => 'À propos de l\'événement';

  @override
  String get startingFrom => 'À partir de';

  @override
  String get scanTickets => 'Scanner les billets';

  @override
  String get getTickets => 'Obtenir des billets';

  @override
  String get freeEntry => 'Entrée gratuite';
}
