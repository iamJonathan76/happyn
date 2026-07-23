// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionAccount => 'Account';

  @override
  String get sectionSocial => 'Social';

  @override
  String get sectionMyActivity => 'My Activity';

  @override
  String get sectionOrganizerTools => 'Organizer Tools';

  @override
  String get sectionSupport => 'Support';

  @override
  String get sectionLegal => 'Legal';

  @override
  String get sectionAbout => 'About';

  @override
  String get sectionAccountActions => 'Account Actions';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get preferences => 'Preferences';

  @override
  String get notificationPreferences => 'Notification Preferences';

  @override
  String get language => 'Language';

  @override
  String get friends => 'Friends';

  @override
  String get following => 'Following';

  @override
  String get followers => 'Followers';

  @override
  String get blockedUsers => 'Blocked Users';

  @override
  String get savedEvents => 'Saved Events';

  @override
  String get eventHistory => 'Event History';

  @override
  String get favoriteOrganizers => 'Favorite Organizers';

  @override
  String get myEvents => 'My Events';

  @override
  String get attendeeManagement => 'Attendee Management';

  @override
  String get analytics => 'Analytics';

  @override
  String get payouts => 'Payouts';

  @override
  String get helpCenter => 'Help Center';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get reportProblem => 'Report a Problem';

  @override
  String get appVersion => 'App Version';

  @override
  String get aboutHappyn => 'About HAPPYN';

  @override
  String get signOut => 'Sign Out';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get soon => 'Soon';

  @override
  String comingSoon(String label) {
    return '$label — coming soon';
  }

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get logIn => 'Log In';

  @override
  String get createAccount => 'Create Account';

  @override
  String get welcomeBack => 'Welcome back 👋';

  @override
  String get joinExperience => 'Join the experience 🎉';

  @override
  String get fullName => 'Full name';

  @override
  String get emailAddress => 'Email address';

  @override
  String get password => 'Password';

  @override
  String get dateOfBirth => 'Date of birth';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get signUp => 'Sign Up';

  @override
  String get orEmail => 'or email';

  @override
  String get appleSignInSoon => 'Apple sign-in coming soon';

  @override
  String get passwordResetSoon => 'Password reset — coming soon';

  @override
  String get bySigningUpAgree => 'By signing up, you agree to our ';

  @override
  String get termsWord => 'Terms';

  @override
  String get andConnector => ' and ';

  @override
  String get privacyWord => 'Privacy Policy';

  @override
  String get errFillAllFields => 'Please fill all required fields';

  @override
  String get errEnterName => 'Please enter your name';

  @override
  String get errEnterDob => 'Please enter your date of birth';

  @override
  String errMinAccountAge(int age) {
    return 'You must be at least $age to use HAPPYN';
  }

  @override
  String get accountCreatedCheckEmail =>
      'Account created. Check your email to confirm your account.';
}
