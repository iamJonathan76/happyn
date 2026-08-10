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

  /// No description provided for @statusUnpublished.
  ///
  /// In en, this message translates to:
  /// **'Unpublished'**
  String get statusUnpublished;

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

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @viewEvent.
  ///
  /// In en, this message translates to:
  /// **'View event'**
  String get viewEvent;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get allCaughtUp;

  /// No description provided for @notifEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Cancellations and event changes will show up here.'**
  String get notifEmptyBody;

  /// No description provided for @timeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeNow;

  /// No description provided for @timeMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{m}m'**
  String timeMinutesShort(int m);

  /// No description provided for @timeHoursShort.
  ///
  /// In en, this message translates to:
  /// **'{h}h'**
  String timeHoursShort(int h);

  /// No description provided for @timeDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{d}d'**
  String timeDaysShort(int d);

  /// No description provided for @timeWeeksShort.
  ///
  /// In en, this message translates to:
  /// **'{w}w'**
  String timeWeeksShort(int w);

  /// No description provided for @createEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get createEventTitle;

  /// No description provided for @editEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get editEventTitle;

  /// No description provided for @generalAdmission.
  ///
  /// In en, this message translates to:
  /// **'General Admission'**
  String get generalAdmission;

  /// No description provided for @tierNameHint.
  ///
  /// In en, this message translates to:
  /// **'Tier name (e.g. VIP)'**
  String get tierNameHint;

  /// No description provided for @qtyHint.
  ///
  /// In en, this message translates to:
  /// **'Qty e.g. 100'**
  String get qtyHint;

  /// No description provided for @priceFreeHint.
  ///
  /// In en, this message translates to:
  /// **'0 = free'**
  String get priceFreeHint;

  /// No description provided for @tierSoldInfo.
  ///
  /// In en, this message translates to:
  /// **'{sold} sold · min quantity {sold}'**
  String tierSoldInfo(int sold);

  /// No description provided for @maxPerPersonHint.
  ///
  /// In en, this message translates to:
  /// **'Max/person (0=∞)'**
  String get maxPerPersonHint;

  /// No description provided for @mustBeOrganizerAge.
  ///
  /// In en, this message translates to:
  /// **'You must be {age}+ to organize an event'**
  String mustBeOrganizerAge(int age);

  /// No description provided for @errEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get errEnterTitle;

  /// No description provided for @errEnterLocation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a location'**
  String get errEnterLocation;

  /// No description provided for @errEnterCity.
  ///
  /// In en, this message translates to:
  /// **'Please enter a city'**
  String get errEnterCity;

  /// No description provided for @errQtyBelowSold.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\": quantity can\'t be below {sold} sold'**
  String errQtyBelowSold(String name, int sold);

  /// No description provided for @errKeepOneTier.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one ticket tier'**
  String get errKeepOneTier;

  /// No description provided for @errAddOneTier.
  ///
  /// In en, this message translates to:
  /// **'Add at least one ticket tier (name + quantity)'**
  String get errAddOneTier;

  /// No description provided for @eventUpdated.
  ///
  /// In en, this message translates to:
  /// **'Event updated ✓'**
  String get eventUpdated;

  /// No description provided for @eventCreated.
  ///
  /// In en, this message translates to:
  /// **'Event created successfully! 🎉'**
  String get eventCreated;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {msg}'**
  String errGeneric(String msg);

  /// No description provided for @inviteShareText.
  ///
  /// In en, this message translates to:
  /// **'Join my event “{title}” on HAPPYN 🎟️\nOpen the app → “Have an invite code?” → enter: {code}'**
  String inviteShareText(String title, String code);

  /// No description provided for @privateEventCreated.
  ///
  /// In en, this message translates to:
  /// **'Private event created 🎉'**
  String get privateEventCreated;

  /// No description provided for @privateEventCreatedBody.
  ///
  /// In en, this message translates to:
  /// **'Only people with this code can find and join your event.'**
  String get privateEventCreatedBody;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied ✓'**
  String get codeCopied;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @inviteCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite copied — paste it anywhere ✓'**
  String get inviteCopied;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @eventTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Event Title *'**
  String get eventTitleLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category *'**
  String get categoryLabel;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Tell people about your event...'**
  String get descriptionHint;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location *'**
  String get locationLabel;

  /// No description provided for @venueHint.
  ///
  /// In en, this message translates to:
  /// **'Venue name or address'**
  String get venueHint;

  /// No description provided for @cityHint.
  ///
  /// In en, this message translates to:
  /// **'City (e.g. Ottawa, ON)'**
  String get cityHint;

  /// No description provided for @dateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Date & Time *'**
  String get dateTimeLabel;

  /// No description provided for @startLabel.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startLabel;

  /// No description provided for @endLabel.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endLabel;

  /// No description provided for @ticketTiersLabel.
  ///
  /// In en, this message translates to:
  /// **'Ticket Tiers *'**
  String get ticketTiersLabel;

  /// No description provided for @addTier.
  ///
  /// In en, this message translates to:
  /// **'Add tier'**
  String get addTier;

  /// No description provided for @coverImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Cover Image'**
  String get coverImageLabel;

  /// No description provided for @tapToChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to choose a cover photo'**
  String get tapToChoosePhoto;

  /// No description provided for @coverOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional — a default image is used if you skip this.'**
  String get coverOptional;

  /// No description provided for @ageRequirementLabel.
  ///
  /// In en, this message translates to:
  /// **'Age requirement'**
  String get ageRequirementLabel;

  /// No description provided for @allAges.
  ///
  /// In en, this message translates to:
  /// **'All Ages'**
  String get allAges;

  /// No description provided for @ageRequirementHelp.
  ///
  /// In en, this message translates to:
  /// **'Attendees below the age are blocked at checkout. Final age check is done at the door by the organizer.'**
  String get ageRequirementHelp;

  /// No description provided for @privateEventLabel.
  ///
  /// In en, this message translates to:
  /// **'Private event'**
  String get privateEventLabel;

  /// No description provided for @privateEventOnHelp.
  ///
  /// In en, this message translates to:
  /// **'Hidden from Discover. Only people with the invite code can join.'**
  String get privateEventOnHelp;

  /// No description provided for @privateEventOffHelp.
  ///
  /// In en, this message translates to:
  /// **'Listed publicly in Discover for everyone.'**
  String get privateEventOffHelp;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code: {code}'**
  String inviteCodeLabel(String code);

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @publishEvent.
  ///
  /// In en, this message translates to:
  /// **'Publish Event'**
  String get publishEvent;

  /// No description provided for @ageBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'This event is {minAge}+. Your account doesn\'t meet the age requirement, so tickets can\'t be purchased.'**
  String ageBlockedBody(int minAge);

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled'**
  String get paymentCancelled;

  /// No description provided for @errEventEndedTickets.
  ///
  /// In en, this message translates to:
  /// **'This event has ended — tickets are closed.'**
  String get errEventEndedTickets;

  /// No description provided for @errLimitPerPerson.
  ///
  /// In en, this message translates to:
  /// **'You reached the limit per person for this ticket.'**
  String get errLimitPerPerson;

  /// No description provided for @errNotEnoughTickets.
  ///
  /// In en, this message translates to:
  /// **'Sorry, not enough tickets left.'**
  String get errNotEnoughTickets;

  /// No description provided for @errSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get errSignInAgain;

  /// No description provided for @errTicketUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This ticket is no longer available.'**
  String get errTicketUnavailable;

  /// No description provided for @errPaymentsNotSetup.
  ///
  /// In en, this message translates to:
  /// **'Payments are not set up yet.'**
  String get errPaymentsNotSetup;

  /// No description provided for @errSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errSomethingWrong;

  /// No description provided for @selectTicketType.
  ///
  /// In en, this message translates to:
  /// **'Select Ticket Type'**
  String get selectTicketType;

  /// No description provided for @onlyLeft.
  ///
  /// In en, this message translates to:
  /// **'Only {n} left'**
  String onlyLeft(int n);

  /// No description provided for @soldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold Out'**
  String get soldOut;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @noTicketsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No tickets available yet'**
  String get noTicketsAvailable;

  /// No description provided for @organizerNoTickets.
  ///
  /// In en, this message translates to:
  /// **'The organizer hasn\'t added tickets yet.'**
  String get organizerNoTickets;

  /// No description provided for @qrLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your ticket QR. Tap to retry.'**
  String get qrLoadError;

  /// No description provided for @myTicket.
  ///
  /// In en, this message translates to:
  /// **'My Ticket'**
  String get myTicket;

  /// No description provided for @ticketCancelledBanner.
  ///
  /// In en, this message translates to:
  /// **'This event was cancelled by the organizer. This ticket is no longer valid.'**
  String get ticketCancelledBanner;

  /// No description provided for @scanAtEntry.
  ///
  /// In en, this message translates to:
  /// **'Scan at entry'**
  String get scanAtEntry;

  /// No description provided for @secureCodeRefreshes.
  ///
  /// In en, this message translates to:
  /// **'Secure code · refreshes automatically'**
  String get secureCodeRefreshes;

  /// No description provided for @ticketDetails.
  ///
  /// In en, this message translates to:
  /// **'Ticket Details'**
  String get ticketDetails;

  /// No description provided for @labelDate.
  ///
  /// In en, this message translates to:
  /// **'DATE'**
  String get labelDate;

  /// No description provided for @labelType.
  ///
  /// In en, this message translates to:
  /// **'TYPE'**
  String get labelType;

  /// No description provided for @labelPrice.
  ///
  /// In en, this message translates to:
  /// **'PRICE'**
  String get labelPrice;

  /// No description provided for @orderId.
  ///
  /// In en, this message translates to:
  /// **'Order ID'**
  String get orderId;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @statusValid.
  ///
  /// In en, this message translates to:
  /// **'Valid ✓'**
  String get statusValid;

  /// No description provided for @venueLabel.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get venueLabel;

  /// No description provided for @transferHint.
  ///
  /// In en, this message translates to:
  /// **'Send this ticket to another HAPPYN user by email.'**
  String get transferHint;

  /// No description provided for @errValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get errValidEmail;

  /// No description provided for @ticketSentTo.
  ///
  /// In en, this message translates to:
  /// **'Ticket sent to {email} 🎟️'**
  String ticketSentTo(String email);

  /// No description provided for @transferTicket.
  ///
  /// In en, this message translates to:
  /// **'Transfer ticket'**
  String get transferTicket;

  /// No description provided for @transferSheetBody.
  ///
  /// In en, this message translates to:
  /// **'The recipient must already have a HAPPYN account. Once sent, this ticket leaves your account.'**
  String get transferSheetBody;

  /// No description provided for @emailHintFriend.
  ///
  /// In en, this message translates to:
  /// **'friend@email.com'**
  String get emailHintFriend;

  /// No description provided for @sendTicket.
  ///
  /// In en, this message translates to:
  /// **'Send ticket'**
  String get sendTicket;

  /// No description provided for @transferErrRecipientNotFound.
  ///
  /// In en, this message translates to:
  /// **'No HAPPYN account found with that email.'**
  String get transferErrRecipientNotFound;

  /// No description provided for @transferErrSelf.
  ///
  /// In en, this message translates to:
  /// **'That ticket is already yours.'**
  String get transferErrSelf;

  /// No description provided for @transferErrNotTransferable.
  ///
  /// In en, this message translates to:
  /// **'This ticket can no longer be transferred.'**
  String get transferErrNotTransferable;

  /// No description provided for @transferErrEventCancelled.
  ///
  /// In en, this message translates to:
  /// **'This event was cancelled.'**
  String get transferErrEventCancelled;

  /// No description provided for @transferErrEventEnded.
  ///
  /// In en, this message translates to:
  /// **'This event has already ended.'**
  String get transferErrEventEnded;

  /// No description provided for @transferFailed.
  ///
  /// In en, this message translates to:
  /// **'Transfer failed. Please try again.'**
  String get transferFailed;

  /// No description provided for @showImGoing.
  ///
  /// In en, this message translates to:
  /// **'Show connections I am going'**
  String get showImGoing;

  /// No description provided for @showImGoingHelp.
  ///
  /// In en, this message translates to:
  /// **'People you follow each other with will see you on this event. Nothing is posted and nobody is notified.'**
  String get showImGoingHelp;

  /// No description provided for @visibilityUpdated.
  ///
  /// In en, this message translates to:
  /// **'Visibility updated'**
  String get visibilityUpdated;

  /// No description provided for @visibilityFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update visibility.'**
  String get visibilityFailed;

  /// No description provided for @myTicketsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Tickets'**
  String get myTicketsTitle;

  /// No description provided for @tabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tabUpcoming;

  /// No description provided for @tabPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get tabPast;

  /// No description provided for @noUpcomingTickets.
  ///
  /// In en, this message translates to:
  /// **'No upcoming tickets'**
  String get noUpcomingTickets;

  /// No description provided for @noPastTickets.
  ///
  /// In en, this message translates to:
  /// **'No past tickets'**
  String get noPastTickets;

  /// No description provided for @discoverAndBuy.
  ///
  /// In en, this message translates to:
  /// **'Discover events and buy your first ticket!'**
  String get discoverAndBuy;

  /// No description provided for @viewQR.
  ///
  /// In en, this message translates to:
  /// **'View QR'**
  String get viewQR;

  /// No description provided for @welcomeIn.
  ///
  /// In en, this message translates to:
  /// **'Welcome in!'**
  String get welcomeIn;

  /// No description provided for @scanAlreadyScanned.
  ///
  /// In en, this message translates to:
  /// **'This ticket has already been scanned.'**
  String get scanAlreadyScanned;

  /// No description provided for @scanExpired.
  ///
  /// In en, this message translates to:
  /// **'The QR code expired. Ask the guest to refresh it.'**
  String get scanExpired;

  /// No description provided for @scanNotOrganizer.
  ///
  /// In en, this message translates to:
  /// **'You are not the organizer of this event.'**
  String get scanNotOrganizer;

  /// No description provided for @scanInvalid.
  ///
  /// In en, this message translates to:
  /// **'This QR code is not a valid HAPPYN ticket.'**
  String get scanInvalid;

  /// No description provided for @scanNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Try again.'**
  String get scanNetworkError;

  /// No description provided for @scanNext.
  ///
  /// In en, this message translates to:
  /// **'Scan next'**
  String get scanNext;

  /// No description provided for @scanTicketsTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan tickets'**
  String get scanTicketsTitle;

  /// No description provided for @scanResultAdmitted.
  ///
  /// In en, this message translates to:
  /// **'Admitted'**
  String get scanResultAdmitted;

  /// No description provided for @scanResultAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'Already used'**
  String get scanResultAlreadyUsed;

  /// No description provided for @scanResultExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get scanResultExpired;

  /// No description provided for @scanResultNotAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Not authorized'**
  String get scanResultNotAuthorized;

  /// No description provided for @scanResultInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get scanResultInvalid;

  /// No description provided for @paymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment received ✓'**
  String get paymentReceived;

  /// No description provided for @issuingTicket.
  ///
  /// In en, this message translates to:
  /// **'Issuing your ticket…'**
  String get issuingTicket;

  /// No description provided for @almostThere.
  ///
  /// In en, this message translates to:
  /// **'Almost there'**
  String get almostThere;

  /// No description provided for @paymentDelayBody.
  ///
  /// In en, this message translates to:
  /// **'Your payment went through. Your ticket is taking a little longer than usual. It will appear in My Tickets shortly.'**
  String get paymentDelayBody;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @statEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get statEvents;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavoritesYet;

  /// No description provided for @tapHeartToSave.
  ///
  /// In en, this message translates to:
  /// **'Tap the ♥ on an event to save it here.'**
  String get tapHeartToSave;

  /// No description provided for @noEventsCreated.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t created any events yet.'**
  String get noEventsCreated;

  /// No description provided for @tapPlusToCreate.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to create your first event!'**
  String get tapPlusToCreate;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @aboutLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get aboutLocation;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get memberSince;

  /// No description provided for @eventDeleted.
  ///
  /// In en, this message translates to:
  /// **'Event deleted'**
  String get eventDeleted;

  /// No description provided for @couldNotDeleteEvent.
  ///
  /// In en, this message translates to:
  /// **'Could not delete this event.'**
  String get couldNotDeleteEvent;

  /// No description provided for @cantDeleteHasTickets.
  ///
  /// In en, this message translates to:
  /// **'Can\'t delete: this event has sold tickets. Cancel it instead.'**
  String get cantDeleteHasTickets;

  /// No description provided for @deleteEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete event?'**
  String get deleteEventTitle;

  /// No description provided for @deleteEventBody.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteEventBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @completeYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get completeYourProfile;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @optionalDoLater.
  ///
  /// In en, this message translates to:
  /// **'Optional — you can do this later in settings.'**
  String get optionalDoLater;

  /// No description provided for @interestsLabel.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get interestsLabel;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// No description provided for @bioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bioLabel;

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save & Continue'**
  String get saveAndContinue;

  /// No description provided for @couldNotSaveLater.
  ///
  /// In en, this message translates to:
  /// **'Could not save. You can do it later in settings.'**
  String get couldNotSaveLater;

  /// No description provided for @cityHintShort.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ottawa, ON'**
  String get cityHintShort;

  /// No description provided for @bioHint.
  ///
  /// In en, this message translates to:
  /// **'A few words about you...'**
  String get bioHint;

  /// No description provided for @yourNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourNameHint;

  /// No description provided for @tapToChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to change photo'**
  String get tapToChangePhoto;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// No description provided for @emailChangesSoon.
  ///
  /// In en, this message translates to:
  /// **'Email changes are coming soon.'**
  String get emailChangesSoon;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated ✓'**
  String get profileUpdated;

  /// No description provided for @couldNotSaveRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Please try again.'**
  String get couldNotSaveRetry;

  /// No description provided for @joinPrivateEvent.
  ///
  /// In en, this message translates to:
  /// **'Join private event'**
  String get joinPrivateEvent;

  /// No description provided for @gotInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Got an invite code?'**
  String get gotInviteCode;

  /// No description provided for @joinPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'Private events don\'t show up in Discover. Enter the code the organizer shared with you to open it.'**
  String get joinPrivateBody;

  /// No description provided for @inviteCodePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'HPN-XXXXX'**
  String get inviteCodePlaceholder;

  /// No description provided for @openEvent.
  ///
  /// In en, this message translates to:
  /// **'Open event'**
  String get openEvent;

  /// No description provided for @errEnterInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the invite code.'**
  String get errEnterInviteCode;

  /// No description provided for @errNoPrivateEvent.
  ///
  /// In en, this message translates to:
  /// **'No private event found for that code.'**
  String get errNoPrivateEvent;

  /// No description provided for @errSomethingWrongRetry.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errSomethingWrongRetry;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navTickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get navTickets;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @onbTitle1.
  ///
  /// In en, this message translates to:
  /// **'Discover Events\nNear You'**
  String get onbTitle1;

  /// No description provided for @onbSub1.
  ///
  /// In en, this message translates to:
  /// **'From underground clubs to rooftop festivals — find what moves you, powered by real-time local intelligence.'**
  String get onbSub1;

  /// No description provided for @onbTitle2.
  ///
  /// In en, this message translates to:
  /// **'Connect With\nYour People'**
  String get onbTitle2;

  /// No description provided for @onbSub2.
  ///
  /// In en, this message translates to:
  /// **'Follow friends, join communities, and always know who is going where before you commit.'**
  String get onbSub2;

  /// No description provided for @onbTitle3.
  ///
  /// In en, this message translates to:
  /// **'Be the Moment'**
  String get onbTitle3;

  /// No description provided for @onbSub3.
  ///
  /// In en, this message translates to:
  /// **'Secure tickets in seconds. QR check-in. No stress, no FOMO. Just pure experience.'**
  String get onbSub3;

  /// No description provided for @onbContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onbContinue;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'FIND THE ONES. BE THE MOMENT.'**
  String get splashTagline;

  /// No description provided for @getDirections.
  ///
  /// In en, this message translates to:
  /// **'Get directions'**
  String get getDirections;

  /// No description provided for @couldNotOpenMaps.
  ///
  /// In en, this message translates to:
  /// **'Could not open a maps app.'**
  String get couldNotOpenMaps;

  /// No description provided for @documentNotFound.
  ///
  /// In en, this message translates to:
  /// **'Document not found'**
  String get documentNotFound;

  /// No description provided for @aboutHappynBody.
  ///
  /// In en, this message translates to:
  /// **'Find the ones. Be the moment.\n\nDiscover, create, and attend events. Version {version}.'**
  String aboutHappynBody(String version);

  /// No description provided for @selectDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth'**
  String get selectDateOfBirth;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This is permanent and cannot be undone. Your profile, photo, favourites and notifications will be deleted.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountRetention.
  ///
  /// In en, this message translates to:
  /// **'Past tickets and past events are kept for legal and accounting reasons, but are detached from your profile. Your past events will show “Organizer deleted”.'**
  String get deleteAccountRetention;

  /// No description provided for @deleteAccountWhatHappens.
  ///
  /// In en, this message translates to:
  /// **'What will happen'**
  String get deleteAccountWhatHappens;

  /// No description provided for @deleteAccountTicketsCancelled.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 upcoming ticket will be cancelled} other{{count} upcoming tickets will be cancelled}}'**
  String deleteAccountTicketsCancelled(int count);

  /// No description provided for @deleteAccountEventsCancelled.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 upcoming event will be cancelled and its attendees notified} other{{count} upcoming events will be cancelled and their attendees notified}}'**
  String deleteAccountEventsCancelled(int count);

  /// No description provided for @deleteAccountEventsDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 upcoming event with no attendee will be deleted} other{{count} upcoming events with no attendee will be deleted}}'**
  String deleteAccountEventsDeleted(int count);

  /// No description provided for @deleteAccountNothingPending.
  ///
  /// In en, this message translates to:
  /// **'You have nothing pending — your account can be deleted right away.'**
  String get deleteAccountNothingPending;

  /// No description provided for @deleteAccountBlocked.
  ///
  /// In en, this message translates to:
  /// **'You have paid ticket sales on an upcoming event. Cancel or refund it first, or contact support@happyn.com.'**
  String get deleteAccountBlocked;

  /// No description provided for @deleteAccountConfirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Type your email address to confirm'**
  String get deleteAccountConfirmEmail;

  /// No description provided for @deleteAccountEmailMismatch.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t match your email address.'**
  String get deleteAccountEmailMismatch;

  /// No description provided for @deleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteMyAccount;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeleted;

  /// No description provided for @deletionFailed.
  ///
  /// In en, this message translates to:
  /// **'Deletion failed. Please try again or contact support@happyn.com.'**
  String get deletionFailed;

  /// No description provided for @moments.
  ///
  /// In en, this message translates to:
  /// **'Moments'**
  String get moments;

  /// No description provided for @momentsFromEvents.
  ///
  /// In en, this message translates to:
  /// **'What people are living right now'**
  String get momentsFromEvents;

  /// No description provided for @feedDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get feedDiscover;

  /// No description provided for @feedFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get feedFollowing;

  /// No description provided for @feedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get feedEmpty;

  /// No description provided for @feedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Be the first to share a moment.'**
  String get feedEmptyBody;

  /// No description provided for @feedFollowingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your feed is quiet'**
  String get feedFollowingEmpty;

  /// No description provided for @feedFollowingEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Follow people to see their posts here.'**
  String get feedFollowingEmptyBody;

  /// No description provided for @onNow.
  ///
  /// In en, this message translates to:
  /// **'Happening soon'**
  String get onNow;

  /// No description provided for @newPost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get newPost;

  /// No description provided for @postCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Say something about it...'**
  String get postCaptionHint;

  /// No description provided for @attachEvent.
  ///
  /// In en, this message translates to:
  /// **'Attach an event'**
  String get attachEvent;

  /// No description provided for @noEventAttached.
  ///
  /// In en, this message translates to:
  /// **'No event'**
  String get noEventAttached;

  /// No description provided for @postShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get postShare;

  /// No description provided for @postCreated.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get postCreated;

  /// No description provided for @postFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not publish. Please try again.'**
  String get postFailed;

  /// No description provided for @postNeedsContent.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or a few words.'**
  String get postNeedsContent;

  /// No description provided for @postNeedsEvent.
  ///
  /// In en, this message translates to:
  /// **'Choose the event this is about.'**
  String get postNeedsEvent;

  /// No description provided for @attachEventRequired.
  ///
  /// In en, this message translates to:
  /// **'Event *'**
  String get attachEventRequired;

  /// No description provided for @chooseEvent.
  ///
  /// In en, this message translates to:
  /// **'Choose an event'**
  String get chooseEvent;

  /// No description provided for @noAttachableEvents.
  ///
  /// In en, this message translates to:
  /// **'You have no event to post about yet. Get a ticket or create an event first.'**
  String get noAttachableEvents;

  /// No description provided for @shareMoment.
  ///
  /// In en, this message translates to:
  /// **'Share a moment'**
  String get shareMoment;

  /// No description provided for @reportPost.
  ///
  /// In en, this message translates to:
  /// **'Report this post'**
  String get reportPost;

  /// No description provided for @deletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get deletePost;

  /// No description provided for @deletePostConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this post? This cannot be undone.'**
  String get deletePostConfirm;

  /// No description provided for @postDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted'**
  String get postDeleted;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @unfollow.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get unfollow;

  /// No description provided for @postsCount.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get postsCount;

  /// No description provided for @createEventChoice.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get createEventChoice;

  /// No description provided for @createPostChoice.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get createPostChoice;

  /// No description provided for @createWhat.
  ///
  /// In en, this message translates to:
  /// **'What do you want to create?'**
  String get createWhat;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @reportEvent.
  ///
  /// In en, this message translates to:
  /// **'Report this event'**
  String get reportEvent;

  /// No description provided for @reportReason.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this?'**
  String get reportReason;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or repetitive'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate or offensive'**
  String get reportReasonInappropriate;

  /// No description provided for @reportReasonScam.
  ///
  /// In en, this message translates to:
  /// **'Scam or fraud'**
  String get reportReasonScam;

  /// No description provided for @reportReasonMisleading.
  ///
  /// In en, this message translates to:
  /// **'Misleading information'**
  String get reportReasonMisleading;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportReasonOther;

  /// No description provided for @reportDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Add details (optional)'**
  String get reportDetailsHint;

  /// No description provided for @reportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportSubmit;

  /// No description provided for @reportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks — our team will review this.'**
  String get reportThanks;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the report. Please try again.'**
  String get reportFailed;

  /// No description provided for @blockOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Block organizer'**
  String get blockOrganizer;

  /// No description provided for @blockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block this organizer?'**
  String get blockConfirmTitle;

  /// No description provided for @blockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will no longer see their events. You can unblock them at any time from Settings.'**
  String get blockConfirmBody;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @userBlocked.
  ///
  /// In en, this message translates to:
  /// **'Organizer blocked.'**
  String get userBlocked;

  /// No description provided for @userUnblocked.
  ///
  /// In en, this message translates to:
  /// **'Organizer unblocked.'**
  String get userUnblocked;

  /// No description provided for @blockedAccount.
  ///
  /// In en, this message translates to:
  /// **'Blocked account'**
  String get blockedAccount;

  /// No description provided for @blockedUsersEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t blocked anyone'**
  String get blockedUsersEmpty;

  /// No description provided for @blockedUsersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Blocked accounts and their events won\'t appear in your feeds.'**
  String get blockedUsersEmptyBody;
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
