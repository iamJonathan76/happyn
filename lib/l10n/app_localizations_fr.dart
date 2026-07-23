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

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Tout marquer comme lu';

  @override
  String get viewEvent => 'Voir l\'événement';

  @override
  String get allCaughtUp => 'Tu es à jour';

  @override
  String get notifEmptyBody =>
      'Les annulations et changements d\'événements apparaîtront ici.';

  @override
  String get timeNow => 'à l\'instant';

  @override
  String timeMinutesShort(int m) {
    return '$m min';
  }

  @override
  String timeHoursShort(int h) {
    return '$h h';
  }

  @override
  String timeDaysShort(int d) {
    return '$d j';
  }

  @override
  String timeWeeksShort(int w) {
    return '$w sem';
  }

  @override
  String get createEventTitle => 'Créer un événement';

  @override
  String get editEventTitle => 'Modifier l\'événement';

  @override
  String get generalAdmission => 'Admission générale';

  @override
  String get tierNameHint => 'Nom du tarif (ex. VIP)';

  @override
  String get qtyHint => 'Qté ex. 100';

  @override
  String get priceFreeHint => '0 = gratuit';

  @override
  String tierSoldInfo(int sold) {
    return '$sold vendus · quantité min $sold';
  }

  @override
  String get maxPerPersonHint => 'Max/pers. (0=∞)';

  @override
  String mustBeOrganizerAge(int age) {
    return 'Vous devez avoir $age ans ou plus pour organiser un événement';
  }

  @override
  String get errEnterTitle => 'Veuillez entrer un titre';

  @override
  String get errEnterLocation => 'Veuillez entrer un lieu';

  @override
  String get errEnterCity => 'Veuillez entrer une ville';

  @override
  String errQtyBelowSold(String name, int sold) {
    return '« $name » : la quantité ne peut pas être inférieure à $sold vendus';
  }

  @override
  String get errKeepOneTier => 'Gardez au moins un tarif de billet';

  @override
  String get errAddOneTier =>
      'Ajoutez au moins un tarif de billet (nom + quantité)';

  @override
  String get eventUpdated => 'Événement mis à jour ✓';

  @override
  String get eventCreated => 'Événement créé avec succès ! 🎉';

  @override
  String errGeneric(String msg) {
    return 'Erreur : $msg';
  }

  @override
  String inviteShareText(String title, String code) {
    return 'Rejoins mon événement « $title » sur HAPPYN 🎟️\nOuvre l\'app → « Un code ? » → entre : $code';
  }

  @override
  String get privateEventCreated => 'Événement privé créé 🎉';

  @override
  String get privateEventCreatedBody =>
      'Seules les personnes ayant ce code peuvent trouver et rejoindre ton événement.';

  @override
  String get codeCopied => 'Code copié ✓';

  @override
  String get copyCode => 'Copier le code';

  @override
  String get inviteCopied => 'Invitation copiée — colle-la où tu veux ✓';

  @override
  String get share => 'Partager';

  @override
  String get done => 'Terminé';

  @override
  String get eventTitleLabel => 'Titre de l\'événement *';

  @override
  String get categoryLabel => 'Catégorie *';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get descriptionHint => 'Parle de ton événement...';

  @override
  String get locationLabel => 'Lieu *';

  @override
  String get venueHint => 'Nom du lieu ou adresse';

  @override
  String get cityHint => 'Ville (ex. Ottawa, ON)';

  @override
  String get dateTimeLabel => 'Date et heure *';

  @override
  String get startLabel => 'Début';

  @override
  String get endLabel => 'Fin';

  @override
  String get ticketTiersLabel => 'Tarifs de billets *';

  @override
  String get addTier => 'Ajouter un tarif';

  @override
  String get coverImageLabel => 'Image de couverture';

  @override
  String get tapToChoosePhoto => 'Touchez pour choisir une photo de couverture';

  @override
  String get coverOptional =>
      'Optionnel — une image par défaut est utilisée si vous passez.';

  @override
  String get ageRequirementLabel => 'Exigence d\'âge';

  @override
  String get allAges => 'Tous âges';

  @override
  String get ageRequirementHelp =>
      'Les participants en dessous de l\'âge sont bloqués au paiement. La vérification finale se fait à la porte par l\'organisateur.';

  @override
  String get privateEventLabel => 'Événement privé';

  @override
  String get privateEventOnHelp =>
      'Masqué de Découvrir. Seules les personnes ayant le code d\'invitation peuvent rejoindre.';

  @override
  String get privateEventOffHelp =>
      'Listé publiquement dans Découvrir pour tout le monde.';

  @override
  String inviteCodeLabel(String code) {
    return 'Code d\'invitation : $code';
  }

  @override
  String get saveChanges => 'Enregistrer';

  @override
  String get publishEvent => 'Publier l\'événement';
}
