import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @sectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get sectionAccount;

  /// No description provided for @sectionSocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get sectionSocial;

  /// No description provided for @sectionMyActivity.
  ///
  /// In en, this message translates to:
  /// **'My Activity'**
  String get sectionMyActivity;

  /// No description provided for @sectionOrganizerTools.
  ///
  /// In en, this message translates to:
  /// **'Organizer Tools'**
  String get sectionOrganizerTools;

  /// No description provided for @sectionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get sectionSupport;

  /// No description provided for @sectionLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get sectionLegal;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @sectionAccountActions.
  ///
  /// In en, this message translates to:
  /// **'Account Actions'**
  String get sectionAccountActions;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @notificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Notification Preferences'**
  String get notificationPreferences;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// No description provided for @following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// No description provided for @followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followers;

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blockedUsers;

  /// No description provided for @savedEvents.
  ///
  /// In en, this message translates to:
  /// **'Saved Events'**
  String get savedEvents;

  /// No description provided for @eventHistory.
  ///
  /// In en, this message translates to:
  /// **'Event History'**
  String get eventHistory;

  /// No description provided for @favoriteOrganizers.
  ///
  /// In en, this message translates to:
  /// **'Favorite Organizers'**
  String get favoriteOrganizers;

  /// No description provided for @myEvents.
  ///
  /// In en, this message translates to:
  /// **'My Events'**
  String get myEvents;

  /// No description provided for @attendeeManagement.
  ///
  /// In en, this message translates to:
  /// **'Attendee Management'**
  String get attendeeManagement;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @payouts.
  ///
  /// In en, this message translates to:
  /// **'Payouts'**
  String get payouts;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @reportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a Problem'**
  String get reportProblem;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @aboutHappyn.
  ///
  /// In en, this message translates to:
  /// **'About HAPPYN'**
  String get aboutHappyn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @soon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get soon;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'{label} — coming soon'**
  String comingSoon(String label);

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back 👋'**
  String get welcomeBack;

  /// No description provided for @joinExperience.
  ///
  /// In en, this message translates to:
  /// **'Join the experience 🎉'**
  String get joinExperience;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dateOfBirth;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @orEmail.
  ///
  /// In en, this message translates to:
  /// **'or email'**
  String get orEmail;

  /// No description provided for @appleSignInSoon.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in coming soon'**
  String get appleSignInSoon;

  /// No description provided for @passwordResetSoon.
  ///
  /// In en, this message translates to:
  /// **'Password reset — coming soon'**
  String get passwordResetSoon;

  /// No description provided for @bySigningUpAgree.
  ///
  /// In en, this message translates to:
  /// **'By signing up, you agree to our '**
  String get bySigningUpAgree;

  /// No description provided for @termsWord.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get termsWord;

  /// No description provided for @andConnector.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get andConnector;

  /// No description provided for @privacyWord.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyWord;

  /// No description provided for @errFillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill all required fields'**
  String get errFillAllFields;

  /// No description provided for @errEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get errEnterName;

  /// No description provided for @errEnterDob.
  ///
  /// In en, this message translates to:
  /// **'Please enter your date of birth'**
  String get errEnterDob;

  /// No description provided for @errMinAccountAge.
  ///
  /// In en, this message translates to:
  /// **'You must be at least {age} to use HAPPYN'**
  String errMinAccountAge(int age);

  /// No description provided for @accountCreatedCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Account created. Check your email to confirm your account.'**
  String get accountCreatedCheckEmail;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search events, artists, venues...'**
  String get searchHint;

  /// No description provided for @eventsToDiscover.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No events to discover} =1{1 event to discover} other{{count} events to discover}}'**
  String eventsToDiscover(int count);

  /// No description provided for @forYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get forYou;

  /// No description provided for @popularNearYou.
  ///
  /// In en, this message translates to:
  /// **'Popular near you'**
  String get popularNearYou;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @couldNotLoadEvents.
  ///
  /// In en, this message translates to:
  /// **'Could not load events'**
  String get couldNotLoadEvents;

  /// No description provided for @noEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No events yet — create the first one! 🎉'**
  String get noEventsYet;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @discoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discoverTitle;

  /// No description provided for @haveACode.
  ///
  /// In en, this message translates to:
  /// **'Have a code?'**
  String get haveACode;

  /// No description provided for @searchHintDiscover.
  ///
  /// In en, this message translates to:
  /// **'Events, venues, artists...'**
  String get searchHintDiscover;

  /// No description provided for @filterTonight.
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get filterTonight;

  /// No description provided for @eventsFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 event found} other{{count} events found}}'**
  String eventsFound(int count);

  /// No description provided for @noResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String noResultsFor(String query);

  /// No description provided for @noEventsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No events in this category yet'**
  String get noEventsInCategory;

  /// No description provided for @tryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or filter'**
  String get tryDifferentSearch;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed. Please try again.'**
  String get actionFailed;

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publish;

  /// No description provided for @unpublish.
  ///
  /// In en, this message translates to:
  /// **'Unpublish'**
  String get unpublish;

  /// No description provided for @cancelEvent.
  ///
  /// In en, this message translates to:
  /// **'Cancel event'**
  String get cancelEvent;

  /// No description provided for @cancelEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this event?'**
  String get cancelEventTitle;

  /// No description provided for @cancelEventBody.
  ///
  /// In en, this message translates to:
  /// **'Ticket holders will be notified and this event will be marked as cancelled. This can\'t be undone.'**
  String get cancelEventBody;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @eventCancelledMsg.
  ///
  /// In en, this message translates to:
  /// **'Event cancelled'**
  String get eventCancelledMsg;

  /// No description provided for @eventPublishedMsg.
  ///
  /// In en, this message translates to:
  /// **'Event published'**
  String get eventPublishedMsg;

  /// No description provided for @eventUnpublishedMsg.
  ///
  /// In en, this message translates to:
  /// **'Event unpublished'**
  String get eventUnpublishedMsg;

  /// No description provided for @tbd.
  ///
  /// In en, this message translates to:
  /// **'TBD'**
  String get tbd;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get statusEnded;

  /// No description provided for @ctaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get ctaUnavailable;

  /// No description provided for @eventEnded.
  ///
  /// In en, this message translates to:
  /// **'Event ended'**
  String get eventEnded;

  /// No description provided for @sharingSoon.
  ///
  /// In en, this message translates to:
  /// **'Sharing — coming soon'**
  String get sharingSoon;

  /// No description provided for @aboutThisEvent.
  ///
  /// In en, this message translates to:
  /// **'About this event'**
  String get aboutThisEvent;

  /// No description provided for @startingFrom.
  ///
  /// In en, this message translates to:
  /// **'Starting from'**
  String get startingFrom;

  /// No description provided for @scanTickets.
  ///
  /// In en, this message translates to:
  /// **'Scan tickets'**
  String get scanTickets;

  /// No description provided for @getTickets.
  ///
  /// In en, this message translates to:
  /// **'Get Tickets'**
  String get getTickets;

  /// No description provided for @freeEntry.
  ///
  /// In en, this message translates to:
  /// **'Free Entry'**
  String get freeEntry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
