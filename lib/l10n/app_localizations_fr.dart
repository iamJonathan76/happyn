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
}
