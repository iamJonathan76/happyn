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
  String get profileTabEvents => 'Événements';

  @override
  String get profileTabPosts => 'Publications';

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
  String get statusUnpublished => 'Dépublié';

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
  String get organizerBadge => 'Organisateur';

  @override
  String get privateEventNeedsCode =>
      'Cet événement est privé. Entre ton code d\'invitation pour l\'ouvrir.';

  @override
  String get postsVisibilityLabel => 'Photos de l\'événement';

  @override
  String get postsInviteesOnly => 'Entre invités';

  @override
  String get postsPublicOption => 'Publiques';

  @override
  String get postsVisibilityHelp =>
      'Qui peut voir les photos publiées sur cet événement. Dans les deux cas l\'événement reste invisible dans Discover — personne ne peut s\'y inviter sans ton code.';

  @override
  String get onInvitationChip => 'Sur invitation';

  @override
  String get filterMyConnections => 'Mes connexions';

  @override
  String get noConnectionEvents =>
      'Aucun événement de tes connexions pour l\'instant. Suivez-vous mutuellement, et les événements qu\'elles choisissent de partager apparaîtront ici.';

  @override
  String supportNoMailApp(String email) {
    return 'Aucune app de courriel trouvée. Écris-nous à $email';
  }

  @override
  String get resetSendTitle => 'Réinitialiser ton mot de passe';

  @override
  String get resetSendBody =>
      'On t\'envoie un lien par courriel pour choisir un nouveau mot de passe. Entre l\'adresse utilisée à l\'inscription.';

  @override
  String get resetSendAction => 'Envoyer le lien';

  @override
  String get resetSent =>
      'Si cette adresse a un compte, un lien vient de partir. Regarde ta boîte de réception et tes indésirables.';

  @override
  String get resetNeedEmail => 'Entre d\'abord ton adresse courriel.';

  @override
  String get soldLabel => 'Billets vendus';

  @override
  String soldOfTotal(int sold, int total) {
    return '$sold / $total';
  }

  @override
  String get attendeesTitle => 'Participants';

  @override
  String get attendeesPeople => 'Personnes';

  @override
  String get attendeesTickets => 'Billets';

  @override
  String get attendeesCheckedIn => 'Arrivés';

  @override
  String get attendeesSearchHint => 'Rechercher un nom';

  @override
  String get attendeesEmpty => 'Aucun billet vendu pour l\'instant.';

  @override
  String get attendeesNoMatch => 'Personne ne correspond à cette recherche.';

  @override
  String get attendeesError => 'Cette liste n\'a pas pu être chargée.';

  @override
  String get attendeeNoName => 'Compte sans nom';

  @override
  String attendeesScannedOf(int scanned, int total) {
    return '$scanned arrivés sur $total';
  }

  @override
  String get moderation => 'Modération';

  @override
  String get moderationQueue => 'Signalements à traiter';

  @override
  String get noReports => 'Rien à traiter. La file est vide.';

  @override
  String get reportedEvent => 'Événement';

  @override
  String get reportedPost => 'Publication';

  @override
  String get reportedUser => 'Compte';

  @override
  String get actionRemove => 'Retirer le contenu';

  @override
  String get actionSuspend => 'Suspendre le compte';

  @override
  String get actionDismiss => 'Non fondé';

  @override
  String get actionDone => 'Signalement traité';

  @override
  String reportedBy(String reason) {
    return 'Motif : $reason';
  }

  @override
  String get moderationFailed => 'Action échouée. Rien n\'a été modifié.';

  @override
  String get adminRemoveConfirm =>
      'Retirer ce contenu en tant que modérateur ? L\'auteur n\'est pas prévenu, et l\'action est inscrite au journal de modération.';

  @override
  String get contentRemoved => 'Contenu retiré';

  @override
  String get cancelTicket => 'Annuler mon billet';

  @override
  String get cancelTicketTitle => 'Annuler ce billet ?';

  @override
  String cancelTicketBodyPaid(String amount) {
    return 'Ta place est rendue et $amount est remboursé sur la carte utilisée. Un remboursement met généralement 5 à 10 jours ouvrables à apparaître.';
  }

  @override
  String get cancelTicketBodyFree =>
      'Ta place est rendue et redevient disponible pour les autres.';

  @override
  String get cancelTicketConfirm => 'Annuler mon billet';

  @override
  String get cancelTicketKeep => 'Le garder';

  @override
  String get cancelTicketDone => 'Billet annulé';

  @override
  String get cancelTicketDoneRefund =>
      'Billet annulé. Le remboursement est en route.';

  @override
  String cancelUntil(String date) {
    return 'Annulation possible jusqu\'au $date';
  }

  @override
  String get cancelErrDeadline =>
      'Le délai d\'annulation pour cet événement est dépassé.';

  @override
  String get cancelErrNotAllowed =>
      'L\'organisateur n\'autorise pas l\'annulation pour cet événement.';

  @override
  String get cancelErrRefund =>
      'Le remboursement n\'a pas pu être effectué, ton billet est donc resté intact. Réessaie ou écris-nous.';

  @override
  String get cancelErrGeneric =>
      'Impossible d\'annuler ce billet. Rien n\'a été modifié.';

  @override
  String get cancellationWindow => 'Délai d\'annulation';

  @override
  String get cancellationWindowHelp =>
      'Combien de temps avant l\'événement un acheteur peut annuler et être remboursé. Choisis « Aucune annulation » pour le refuser.';

  @override
  String get cancellationNone => 'Aucune annulation';

  @override
  String cancellationHours(int hours) {
    return '$hours h avant';
  }

  @override
  String get addressLabel => 'Adresse exacte';

  @override
  String get addressHint => 'Commence à taper une adresse…';

  @override
  String get addressSearching => 'Recherche…';

  @override
  String get addressNoResult =>
      'Aucune adresse trouvée. Vérifie l\'orthographe, ou essaie la rue et la ville.';

  @override
  String get addressChange => 'Modifier';

  @override
  String get addressConfirmed => 'Adresse confirmée';

  @override
  String get addressPrivateNotice =>
      'Pour un événement privé, l\'adresse exacte n\'est révélée qu\'aux personnes qui ont un billet. Le nom du lieu ci-dessous reste public.';

  @override
  String get addressRevealedWithTicket =>
      'Adresse exacte révélée une fois le billet obtenu';

  @override
  String get errPickAddress =>
      'Choisis une adresse dans les suggestions pour qu\'on puisse placer ton événement sur la carte.';

  @override
  String get nearYouTitle => 'Autour de toi';

  @override
  String get nearYouIntro => 'Découvre ce qui se passe près de toi';

  @override
  String get nearYouIntroBody =>
      'Autorise HAPPYN à utiliser ta position pour voir les événements à proximité. Tu peux aussi simplement choisir une ville.';

  @override
  String get useMyLocation => 'Utiliser ma position';

  @override
  String get chooseACity => 'Choisir une ville';

  @override
  String get chooseYourCity => 'Choisis ta ville';

  @override
  String eventsAround(String city) {
    return 'Événements autour de $city';
  }

  @override
  String eventsIn(String city) {
    return 'Événements à $city';
  }

  @override
  String kmAway(String km) {
    return 'à $km km';
  }

  @override
  String get locationRefused =>
      'Pas de souci — choisis plutôt une ville et on te montre ce qui s\'y passe.';

  @override
  String get nothingNearby => 'Rien autour de toi pour l\'instant 👀';

  @override
  String get nothingNearbyBody =>
      'La communauté HAPPYN grandit encore dans ton coin.';

  @override
  String get exploreAllEvents => 'Voir tous les événements';

  @override
  String get changeLocation => 'Changer de localisation';

  @override
  String get locationSection => 'Localisation';

  @override
  String get locationUsingGps => 'Position de l\'appareil';

  @override
  String locationUsingCity(String city) {
    return '$city';
  }

  @override
  String get locationNotSet => 'Non définie';

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

  @override
  String ageBlockedBody(int minAge) {
    return 'Cet événement est $minAge+. Ton compte ne répond pas à l\'exigence d\'âge, l\'achat de billets est donc impossible.';
  }

  @override
  String get paymentCancelled => 'Paiement annulé';

  @override
  String get errEventEndedTickets =>
      'Cet événement est terminé — les billets sont fermés.';

  @override
  String get errLimitPerPerson =>
      'Tu as atteint la limite par personne pour ce billet.';

  @override
  String get errNotEnoughTickets => 'Désolé, il ne reste pas assez de billets.';

  @override
  String get errSignInAgain => 'Veuillez vous reconnecter.';

  @override
  String get errTicketUnavailable => 'Ce billet n\'est plus disponible.';

  @override
  String get errPaymentsNotSetup =>
      'Les paiements ne sont pas encore configurés.';

  @override
  String get errSomethingWrong =>
      'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get selectTicketType => 'Choisir le type de billet';

  @override
  String onlyLeft(int n) {
    return 'Plus que $n';
  }

  @override
  String get soldOut => 'Épuisé';

  @override
  String get quantity => 'Quantité';

  @override
  String get total => 'Total';

  @override
  String get checkout => 'Payer';

  @override
  String get noTicketsAvailable => 'Aucun billet disponible pour l\'instant';

  @override
  String get organizerNoTickets =>
      'L\'organisateur n\'a pas encore ajouté de billets.';

  @override
  String get qrLoadError =>
      'Impossible de charger le QR de ton billet. Touche pour réessayer.';

  @override
  String get myTicket => 'Mon billet';

  @override
  String get ticketCancelledBanner =>
      'Cet événement a été annulé par l\'organisateur. Ce billet n\'est plus valide.';

  @override
  String get scanAtEntry => 'Scanner à l\'entrée';

  @override
  String get secureCodeRefreshes =>
      'Code sécurisé · se rafraîchit automatiquement';

  @override
  String get ticketDetails => 'Détails du billet';

  @override
  String get labelDate => 'DATE';

  @override
  String get labelType => 'TYPE';

  @override
  String get labelPrice => 'PRIX';

  @override
  String get orderId => 'N° de commande';

  @override
  String get typeLabel => 'Type';

  @override
  String get statusLabel => 'Statut';

  @override
  String get statusValid => 'Valide ✓';

  @override
  String get venueLabel => 'Lieu';

  @override
  String get transferHint =>
      'Envoie ce billet à un autre utilisateur HAPPYN par e-mail.';

  @override
  String get errValidEmail => 'Entrez une adresse e-mail valide.';

  @override
  String ticketSentTo(String email) {
    return 'Billet envoyé à $email 🎟️';
  }

  @override
  String get transferTicket => 'Transférer le billet';

  @override
  String get transferSheetBody =>
      'Le destinataire doit déjà avoir un compte HAPPYN. Une fois envoyé, ce billet quitte ton compte.';

  @override
  String get emailHintFriend => 'ami@email.com';

  @override
  String get sendTicket => 'Envoyer le billet';

  @override
  String get transferErrRecipientNotFound =>
      'Aucun compte HAPPYN trouvé avec cet e-mail.';

  @override
  String get transferErrSelf => 'Ce billet est déjà le tien.';

  @override
  String get transferErrNotTransferable =>
      'Ce billet ne peut plus être transféré.';

  @override
  String get transferErrEventCancelled => 'Cet événement a été annulé.';

  @override
  String get transferErrEventEnded => 'Cet événement est déjà terminé.';

  @override
  String get transferFailed => 'Échec du transfert. Veuillez réessayer.';

  @override
  String get whosGoing => 'Qui y va';

  @override
  String connectionsGoing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes que tu connais y vont',
      one: '1 personne que tu connais y va',
    );
    return '$_temp0';
  }

  @override
  String get attendedLabel => 'Y était';

  @override
  String get showImGoing => 'Montrer à mes connexions que j\'y vais';

  @override
  String get showImGoingHelp =>
      'Les personnes que tu suis mutuellement te verront sur cet événement. Rien n\'est publié et personne n\'est notifié.';

  @override
  String get visibilityUpdated => 'Visibilité mise à jour';

  @override
  String get visibilityFailed => 'Impossible de mettre à jour la visibilité.';

  @override
  String get myTicketsTitle => 'Mes billets';

  @override
  String get tabUpcoming => 'À venir';

  @override
  String get tabPast => 'Passés';

  @override
  String get noUpcomingTickets => 'Aucun billet à venir';

  @override
  String get noPastTickets => 'Aucun billet passé';

  @override
  String get discoverAndBuy =>
      'Découvre des événements et achète ton premier billet !';

  @override
  String get viewQR => 'Voir le QR';

  @override
  String get welcomeIn => 'Bienvenue !';

  @override
  String get scanAlreadyScanned => 'Ce billet a déjà été scanné.';

  @override
  String get scanExpired =>
      'Le QR code a expiré. Demande à l\'invité de le rafraîchir.';

  @override
  String get scanNotOrganizer =>
      'Tu n\'es pas l\'organisateur de cet événement.';

  @override
  String get scanInvalid => 'Ce QR code n\'est pas un billet HAPPYN valide.';

  @override
  String get scanNetworkError => 'Erreur réseau. Réessaie.';

  @override
  String get scanNext => 'Scanner le suivant';

  @override
  String get scanTicketsTitle => 'Scanner les billets';

  @override
  String get scanResultAdmitted => 'Admis';

  @override
  String get scanResultAlreadyUsed => 'Déjà utilisé';

  @override
  String get scanResultExpired => 'Expiré';

  @override
  String get scanResultNotAuthorized => 'Non autorisé';

  @override
  String get scanResultInvalid => 'Invalide';

  @override
  String get paymentReceived => 'Paiement reçu ✓';

  @override
  String get issuingTicket => 'Émission de ton billet…';

  @override
  String get almostThere => 'Presque terminé';

  @override
  String get paymentDelayBody =>
      'Ton paiement a été accepté. Ton billet prend un peu plus de temps que d\'habitude. Il apparaîtra bientôt dans Mes billets.';

  @override
  String get backToHome => 'Retour à l\'accueil';

  @override
  String get statEvents => 'Événements';

  @override
  String get favorites => 'Favoris';

  @override
  String get noFavoritesYet => 'Aucun favori pour l\'instant';

  @override
  String get tapHeartToSave =>
      'Touche le ♥ d\'un événement pour l\'enregistrer ici.';

  @override
  String get noEventsCreated => 'Tu n\'as pas encore créé d\'événement.';

  @override
  String get tapPlusToCreate =>
      'Touche le bouton + pour créer ton premier événement !';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get aboutLocation => 'Emplacement';

  @override
  String get memberSince => 'Membre depuis';

  @override
  String get eventDeleted => 'Événement supprimé';

  @override
  String get couldNotDeleteEvent => 'Impossible de supprimer cet événement.';

  @override
  String get cantDeleteHasTickets =>
      'Suppression impossible : cet événement a des billets vendus. Annule-le plutôt.';

  @override
  String get deleteEventTitle => 'Supprimer l\'événement ?';

  @override
  String get deleteEventBody => 'Cette action est irréversible.';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get completeYourProfile => 'Complète ton profil';

  @override
  String get skip => 'Passer';

  @override
  String get optionalDoLater =>
      'Optionnel — tu peux le faire plus tard dans les réglages.';

  @override
  String get interestsLabel => 'Centres d\'intérêt';

  @override
  String get cityLabel => 'Ville';

  @override
  String get bioLabel => 'Bio';

  @override
  String get saveAndContinue => 'Enregistrer et continuer';

  @override
  String get couldNotSaveLater =>
      'Impossible d\'enregistrer. Tu pourras le faire plus tard dans les réglages.';

  @override
  String get cityHintShort => 'ex. Ottawa, ON';

  @override
  String get bioHint => 'Quelques mots sur toi...';

  @override
  String get yourNameHint => 'Ton nom';

  @override
  String get tapToChangePhoto => 'Touche pour changer la photo';

  @override
  String get fullNameLabel => 'Nom complet';

  @override
  String get emailChangesSoon => 'La modification de l\'e-mail arrive bientôt.';

  @override
  String get profileUpdated => 'Profil mis à jour ✓';

  @override
  String get couldNotSaveRetry =>
      'Impossible d\'enregistrer. Veuillez réessayer.';

  @override
  String get joinPrivateEvent => 'Rejoindre un événement privé';

  @override
  String get gotInviteCode => 'Tu as un code d\'invitation ?';

  @override
  String get joinPrivateBody =>
      'Les événements privés n\'apparaissent pas dans Découvrir. Entre le code que l\'organisateur t\'a partagé pour l\'ouvrir.';

  @override
  String get inviteCodePlaceholder => 'HPN-XXXXX';

  @override
  String get openEvent => 'Ouvrir l\'événement';

  @override
  String get errEnterInviteCode => 'Entre le code d\'invitation.';

  @override
  String get errNoPrivateEvent => 'Aucun événement privé trouvé pour ce code.';

  @override
  String get errSomethingWrongRetry =>
      'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get navHome => 'Accueil';

  @override
  String get navDiscover => 'Découvrir';

  @override
  String get navTickets => 'Billets';

  @override
  String get navProfile => 'Profil';

  @override
  String get onbTitle1 => 'Découvre des événements\nprès de toi';

  @override
  String get onbSub1 =>
      'Des clubs underground aux festivals sur les toits — trouve ce qui te fait vibrer, grâce à l\'intelligence locale en temps réel.';

  @override
  String get onbTitle2 => 'Connecte-toi\nà tes proches';

  @override
  String get onbSub2 =>
      'Suis tes amis, rejoins des communautés, et sache toujours qui va où avant de t\'engager.';

  @override
  String get onbTitle3 => 'Vis l\'instant';

  @override
  String get onbSub3 =>
      'Des billets sécurisés en quelques secondes. Check-in par QR. Zéro stress, zéro FOMO. Juste l\'expérience.';

  @override
  String get onbContinue => 'Continuer';

  @override
  String get getStarted => 'Commencer';

  @override
  String get splashTagline => 'TROUVE LES BONS. VIS L\'INSTANT.';

  @override
  String get getDirections => 'Itinéraire';

  @override
  String get couldNotOpenMaps => 'Impossible d\'ouvrir une app de cartes.';

  @override
  String get documentNotFound => 'Document introuvable';

  @override
  String aboutHappynBody(String version) {
    return 'Trouve les bons. Vis l\'instant.\n\nDécouvre, crée et participe à des événements. Version $version.';
  }

  @override
  String get selectDateOfBirth => 'Sélectionne ta date de naissance';

  @override
  String get deleteAccountWarning =>
      'C\'est définitif et irréversible. Ton profil, ta photo, tes favoris et tes notifications seront supprimés.';

  @override
  String get deleteAccountRetention =>
      'Les billets et événements passés sont conservés pour des raisons légales et comptables, mais détachés de ton profil. Tes événements passés afficheront « Organisateur supprimé ».';

  @override
  String get deleteAccountWhatHappens => 'Ce qui va se passer';

  @override
  String deleteAccountTicketsCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count billets à venir seront annulés',
      one: '1 billet à venir sera annulé',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountEventsCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count événements à venir seront annulés et leurs participants notifiés',
      one: '1 événement à venir sera annulé et ses participants notifiés',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountEventsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements à venir sans participant seront supprimés',
      one: '1 événement à venir sans participant sera supprimé',
    );
    return '$_temp0';
  }

  @override
  String get deleteAccountNothingPending =>
      'Tu n\'as rien en cours — ton compte peut être supprimé immédiatement.';

  @override
  String get deleteAccountBlocked =>
      'Tu as des ventes de billets payants sur un événement à venir. Annule-le ou rembourse d\'abord, ou écris à support@happyn.com.';

  @override
  String get deleteAccountConfirmEmail =>
      'Saisis ton adresse e-mail pour confirmer';

  @override
  String get deleteAccountEmailMismatch =>
      'Cela ne correspond pas à ton adresse e-mail.';

  @override
  String get deleteMyAccount => 'Supprimer mon compte';

  @override
  String get accountDeleted => 'Ton compte a été supprimé.';

  @override
  String get deletionFailed =>
      'La suppression a échoué. Réessaie ou écris à support@happyn.com.';

  @override
  String get moments => 'Moments';

  @override
  String get momentsFromEvents => 'Ce que les gens vivent en ce moment';

  @override
  String get feedDiscover => 'Découvrir';

  @override
  String get feedFollowing => 'Abonnements';

  @override
  String get feedEmpty => 'Rien ici pour l\'instant';

  @override
  String get feedEmptyBody => 'Sois le premier à partager un moment.';

  @override
  String get feedFollowingEmpty => 'Ton fil est calme';

  @override
  String get feedFollowingEmptyBody =>
      'Abonne-toi à des comptes pour voir leurs publications ici.';

  @override
  String get onNow => 'Bientôt';

  @override
  String get newPost => 'Nouvelle publication';

  @override
  String get postCaptionHint => 'Dis-en un mot...';

  @override
  String get attachEvent => 'Rattacher un événement';

  @override
  String get noEventAttached => 'Aucun événement';

  @override
  String get postShare => 'Partager';

  @override
  String get postCreated => 'Publié';

  @override
  String get postFailed => 'Impossible de publier. Réessaie.';

  @override
  String get postNeedsContent => 'Ajoute une photo ou quelques mots.';

  @override
  String get postNeedsEvent => 'Choisis l\'événement dont il s\'agit.';

  @override
  String get attachEventRequired => 'Événement *';

  @override
  String get chooseEvent => 'Choisir un événement';

  @override
  String get noAttachableEvents =>
      'Tu n\'as encore aucun événement à raconter. Prends un billet ou crée un événement.';

  @override
  String get shareMoment => 'Partager un moment';

  @override
  String get reportPost => 'Signaler cette publication';

  @override
  String get deletePost => 'Supprimer la publication';

  @override
  String get deletePostConfirm =>
      'Supprimer cette publication ? C\'est irréversible.';

  @override
  String get postDeleted => 'Publication supprimée';

  @override
  String get follow => 'Suivre';

  @override
  String get unfollow => 'Abonné';

  @override
  String get postsCount => 'Publications';

  @override
  String get createEventChoice => 'Événement';

  @override
  String get createPostChoice => 'Publication';

  @override
  String get createWhat => 'Que veux-tu créer ?';

  @override
  String get report => 'Signaler';

  @override
  String get reportEvent => 'Signaler cet événement';

  @override
  String get reportReason => 'Pourquoi le signales-tu ?';

  @override
  String get reportReasonSpam => 'Spam ou répétitif';

  @override
  String get reportReasonInappropriate => 'Inapproprié ou offensant';

  @override
  String get reportReasonScam => 'Arnaque ou fraude';

  @override
  String get reportReasonMisleading => 'Information trompeuse';

  @override
  String get reportReasonOther => 'Autre chose';

  @override
  String get reportDetailsHint => 'Ajouter des précisions (optionnel)';

  @override
  String get reportSubmit => 'Envoyer le signalement';

  @override
  String get reportThanks => 'Merci — notre équipe va examiner ça.';

  @override
  String get reportFailed => 'Impossible d\'envoyer le signalement. Réessaie.';

  @override
  String get blockOrganizer => 'Bloquer l\'organisateur';

  @override
  String get blockConfirmTitle => 'Bloquer cet organisateur ?';

  @override
  String get blockConfirmBody =>
      'Tu ne verras plus ses événements. Tu peux le débloquer à tout moment depuis les Paramètres.';

  @override
  String get block => 'Bloquer';

  @override
  String get unblock => 'Débloquer';

  @override
  String get userBlocked => 'Organisateur bloqué.';

  @override
  String get userUnblocked => 'Organisateur débloqué.';

  @override
  String get blockedAccount => 'Compte bloqué';

  @override
  String get blockedUsersEmpty => 'Tu n\'as bloqué personne';

  @override
  String get blockedUsersEmptyBody =>
      'Les comptes bloqués et leurs événements n\'apparaîtront pas dans tes fils.';
}
