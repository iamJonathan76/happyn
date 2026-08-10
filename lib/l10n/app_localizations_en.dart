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

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get searchHint => 'Search events, artists, venues...';

  @override
  String eventsToDiscover(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events to discover',
      one: '1 event to discover',
      zero: 'No events to discover',
    );
    return '$_temp0';
  }

  @override
  String get forYou => 'For you';

  @override
  String get popularNearYou => 'Popular near you';

  @override
  String get seeAll => 'See all';

  @override
  String get couldNotLoadEvents => 'Could not load events';

  @override
  String get noEventsYet => 'No events yet — create the first one! 🎉';

  @override
  String get categoryAll => 'All';

  @override
  String get free => 'Free';

  @override
  String get discoverTitle => 'Discover';

  @override
  String get haveACode => 'Have a code?';

  @override
  String get searchHintDiscover => 'Events, venues, artists...';

  @override
  String get filterTonight => 'Tonight';

  @override
  String eventsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events found',
      one: '1 event found',
    );
    return '$_temp0';
  }

  @override
  String noResultsFor(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get noEventsInCategory => 'No events in this category yet';

  @override
  String get tryDifferentSearch => 'Try a different search or filter';

  @override
  String get actionFailed => 'Action failed. Please try again.';

  @override
  String get publish => 'Publish';

  @override
  String get unpublish => 'Unpublish';

  @override
  String get cancelEvent => 'Cancel event';

  @override
  String get cancelEventTitle => 'Cancel this event?';

  @override
  String get cancelEventBody =>
      'Ticket holders will be notified and this event will be marked as cancelled. This can\'t be undone.';

  @override
  String get keep => 'Keep';

  @override
  String get eventCancelledMsg => 'Event cancelled';

  @override
  String get eventPublishedMsg => 'Event published';

  @override
  String get eventUnpublishedMsg => 'Event unpublished';

  @override
  String get tbd => 'TBD';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusEnded => 'Ended';

  @override
  String get statusUnpublished => 'Unpublished';

  @override
  String get ctaUnavailable => 'Unavailable';

  @override
  String get eventEnded => 'Event ended';

  @override
  String get sharingSoon => 'Sharing — coming soon';

  @override
  String get aboutThisEvent => 'About this event';

  @override
  String get startingFrom => 'Starting from';

  @override
  String get scanTickets => 'Scan tickets';

  @override
  String get getTickets => 'Get Tickets';

  @override
  String get freeEntry => 'Free Entry';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get viewEvent => 'View event';

  @override
  String get allCaughtUp => 'You\'re all caught up';

  @override
  String get notifEmptyBody =>
      'Cancellations and event changes will show up here.';

  @override
  String get timeNow => 'now';

  @override
  String timeMinutesShort(int m) {
    return '${m}m';
  }

  @override
  String timeHoursShort(int h) {
    return '${h}h';
  }

  @override
  String timeDaysShort(int d) {
    return '${d}d';
  }

  @override
  String timeWeeksShort(int w) {
    return '${w}w';
  }

  @override
  String get createEventTitle => 'Create Event';

  @override
  String get editEventTitle => 'Edit Event';

  @override
  String get generalAdmission => 'General Admission';

  @override
  String get tierNameHint => 'Tier name (e.g. VIP)';

  @override
  String get qtyHint => 'Qty e.g. 100';

  @override
  String get priceFreeHint => '0 = free';

  @override
  String tierSoldInfo(int sold) {
    return '$sold sold · min quantity $sold';
  }

  @override
  String get maxPerPersonHint => 'Max/person (0=∞)';

  @override
  String mustBeOrganizerAge(int age) {
    return 'You must be $age+ to organize an event';
  }

  @override
  String get errEnterTitle => 'Please enter a title';

  @override
  String get errEnterLocation => 'Please enter a location';

  @override
  String get errEnterCity => 'Please enter a city';

  @override
  String errQtyBelowSold(String name, int sold) {
    return '\"$name\": quantity can\'t be below $sold sold';
  }

  @override
  String get errKeepOneTier => 'Keep at least one ticket tier';

  @override
  String get errAddOneTier => 'Add at least one ticket tier (name + quantity)';

  @override
  String get eventUpdated => 'Event updated ✓';

  @override
  String get eventCreated => 'Event created successfully! 🎉';

  @override
  String errGeneric(String msg) {
    return 'Error: $msg';
  }

  @override
  String inviteShareText(String title, String code) {
    return 'Join my event “$title” on HAPPYN 🎟️\nOpen the app → “Have an invite code?” → enter: $code';
  }

  @override
  String get privateEventCreated => 'Private event created 🎉';

  @override
  String get privateEventCreatedBody =>
      'Only people with this code can find and join your event.';

  @override
  String get codeCopied => 'Code copied ✓';

  @override
  String get copyCode => 'Copy code';

  @override
  String get inviteCopied => 'Invite copied — paste it anywhere ✓';

  @override
  String get share => 'Share';

  @override
  String get done => 'Done';

  @override
  String get eventTitleLabel => 'Event Title *';

  @override
  String get categoryLabel => 'Category *';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get descriptionHint => 'Tell people about your event...';

  @override
  String get locationLabel => 'Location *';

  @override
  String get venueHint => 'Venue name or address';

  @override
  String get cityHint => 'City (e.g. Ottawa, ON)';

  @override
  String get dateTimeLabel => 'Date & Time *';

  @override
  String get startLabel => 'Start';

  @override
  String get endLabel => 'End';

  @override
  String get ticketTiersLabel => 'Ticket Tiers *';

  @override
  String get addTier => 'Add tier';

  @override
  String get coverImageLabel => 'Cover Image';

  @override
  String get tapToChoosePhoto => 'Tap to choose a cover photo';

  @override
  String get coverOptional =>
      'Optional — a default image is used if you skip this.';

  @override
  String get ageRequirementLabel => 'Age requirement';

  @override
  String get allAges => 'All Ages';

  @override
  String get ageRequirementHelp =>
      'Attendees below the age are blocked at checkout. Final age check is done at the door by the organizer.';

  @override
  String get privateEventLabel => 'Private event';

  @override
  String get privateEventOnHelp =>
      'Hidden from Discover. Only people with the invite code can join.';

  @override
  String get privateEventOffHelp => 'Listed publicly in Discover for everyone.';

  @override
  String inviteCodeLabel(String code) {
    return 'Invite code: $code';
  }

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get publishEvent => 'Publish Event';

  @override
  String ageBlockedBody(int minAge) {
    return 'This event is $minAge+. Your account doesn\'t meet the age requirement, so tickets can\'t be purchased.';
  }

  @override
  String get paymentCancelled => 'Payment cancelled';

  @override
  String get errEventEndedTickets =>
      'This event has ended — tickets are closed.';

  @override
  String get errLimitPerPerson =>
      'You reached the limit per person for this ticket.';

  @override
  String get errNotEnoughTickets => 'Sorry, not enough tickets left.';

  @override
  String get errSignInAgain => 'Please sign in again.';

  @override
  String get errTicketUnavailable => 'This ticket is no longer available.';

  @override
  String get errPaymentsNotSetup => 'Payments are not set up yet.';

  @override
  String get errSomethingWrong => 'Something went wrong. Please try again.';

  @override
  String get selectTicketType => 'Select Ticket Type';

  @override
  String onlyLeft(int n) {
    return 'Only $n left';
  }

  @override
  String get soldOut => 'Sold Out';

  @override
  String get quantity => 'Quantity';

  @override
  String get total => 'Total';

  @override
  String get checkout => 'Checkout';

  @override
  String get noTicketsAvailable => 'No tickets available yet';

  @override
  String get organizerNoTickets => 'The organizer hasn\'t added tickets yet.';

  @override
  String get qrLoadError => 'Could not load your ticket QR. Tap to retry.';

  @override
  String get myTicket => 'My Ticket';

  @override
  String get ticketCancelledBanner =>
      'This event was cancelled by the organizer. This ticket is no longer valid.';

  @override
  String get scanAtEntry => 'Scan at entry';

  @override
  String get secureCodeRefreshes => 'Secure code · refreshes automatically';

  @override
  String get ticketDetails => 'Ticket Details';

  @override
  String get labelDate => 'DATE';

  @override
  String get labelType => 'TYPE';

  @override
  String get labelPrice => 'PRICE';

  @override
  String get orderId => 'Order ID';

  @override
  String get typeLabel => 'Type';

  @override
  String get statusLabel => 'Status';

  @override
  String get statusValid => 'Valid ✓';

  @override
  String get venueLabel => 'Venue';

  @override
  String get transferHint =>
      'Send this ticket to another HAPPYN user by email.';

  @override
  String get errValidEmail => 'Enter a valid email address.';

  @override
  String ticketSentTo(String email) {
    return 'Ticket sent to $email 🎟️';
  }

  @override
  String get transferTicket => 'Transfer ticket';

  @override
  String get transferSheetBody =>
      'The recipient must already have a HAPPYN account. Once sent, this ticket leaves your account.';

  @override
  String get emailHintFriend => 'friend@email.com';

  @override
  String get sendTicket => 'Send ticket';

  @override
  String get transferErrRecipientNotFound =>
      'No HAPPYN account found with that email.';

  @override
  String get transferErrSelf => 'That ticket is already yours.';

  @override
  String get transferErrNotTransferable =>
      'This ticket can no longer be transferred.';

  @override
  String get transferErrEventCancelled => 'This event was cancelled.';

  @override
  String get transferErrEventEnded => 'This event has already ended.';

  @override
  String get transferFailed => 'Transfer failed. Please try again.';

  @override
  String get myTicketsTitle => 'My Tickets';

  @override
  String get tabUpcoming => 'Upcoming';

  @override
  String get tabPast => 'Past';

  @override
  String get noUpcomingTickets => 'No upcoming tickets';

  @override
  String get noPastTickets => 'No past tickets';

  @override
  String get discoverAndBuy => 'Discover events and buy your first ticket!';

  @override
  String get viewQR => 'View QR';

  @override
  String get welcomeIn => 'Welcome in!';

  @override
  String get scanAlreadyScanned => 'This ticket has already been scanned.';

  @override
  String get scanExpired => 'The QR code expired. Ask the guest to refresh it.';

  @override
  String get scanNotOrganizer => 'You are not the organizer of this event.';

  @override
  String get scanInvalid => 'This QR code is not a valid HAPPYN ticket.';

  @override
  String get scanNetworkError => 'Network error. Try again.';

  @override
  String get scanNext => 'Scan next';

  @override
  String get scanTicketsTitle => 'Scan tickets';

  @override
  String get scanResultAdmitted => 'Admitted';

  @override
  String get scanResultAlreadyUsed => 'Already used';

  @override
  String get scanResultExpired => 'Expired';

  @override
  String get scanResultNotAuthorized => 'Not authorized';

  @override
  String get scanResultInvalid => 'Invalid';

  @override
  String get paymentReceived => 'Payment received ✓';

  @override
  String get issuingTicket => 'Issuing your ticket…';

  @override
  String get almostThere => 'Almost there';

  @override
  String get paymentDelayBody =>
      'Your payment went through. Your ticket is taking a little longer than usual. It will appear in My Tickets shortly.';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get statEvents => 'Events';

  @override
  String get favorites => 'Favorites';

  @override
  String get noFavoritesYet => 'No favorites yet';

  @override
  String get tapHeartToSave => 'Tap the ♥ on an event to save it here.';

  @override
  String get noEventsCreated => 'You haven\'t created any events yet.';

  @override
  String get tapPlusToCreate => 'Tap the + button to create your first event!';

  @override
  String get emailLabel => 'Email';

  @override
  String get aboutLocation => 'Location';

  @override
  String get memberSince => 'Member since';

  @override
  String get eventDeleted => 'Event deleted';

  @override
  String get couldNotDeleteEvent => 'Could not delete this event.';

  @override
  String get cantDeleteHasTickets =>
      'Can\'t delete: this event has sold tickets. Cancel it instead.';

  @override
  String get deleteEventTitle => 'Delete event?';

  @override
  String get deleteEventBody => 'This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get completeYourProfile => 'Complete your profile';

  @override
  String get skip => 'Skip';

  @override
  String get optionalDoLater => 'Optional — you can do this later in settings.';

  @override
  String get interestsLabel => 'Interests';

  @override
  String get cityLabel => 'City';

  @override
  String get bioLabel => 'Bio';

  @override
  String get saveAndContinue => 'Save & Continue';

  @override
  String get couldNotSaveLater =>
      'Could not save. You can do it later in settings.';

  @override
  String get cityHintShort => 'e.g. Ottawa, ON';

  @override
  String get bioHint => 'A few words about you...';

  @override
  String get yourNameHint => 'Your name';

  @override
  String get tapToChangePhoto => 'Tap to change photo';

  @override
  String get fullNameLabel => 'Full Name';

  @override
  String get emailChangesSoon => 'Email changes are coming soon.';

  @override
  String get profileUpdated => 'Profile updated ✓';

  @override
  String get couldNotSaveRetry => 'Could not save. Please try again.';

  @override
  String get joinPrivateEvent => 'Join private event';

  @override
  String get gotInviteCode => 'Got an invite code?';

  @override
  String get joinPrivateBody =>
      'Private events don\'t show up in Discover. Enter the code the organizer shared with you to open it.';

  @override
  String get inviteCodePlaceholder => 'HPN-XXXXX';

  @override
  String get openEvent => 'Open event';

  @override
  String get errEnterInviteCode => 'Enter the invite code.';

  @override
  String get errNoPrivateEvent => 'No private event found for that code.';

  @override
  String get errSomethingWrongRetry =>
      'Something went wrong. Please try again.';

  @override
  String get navHome => 'Home';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navTickets => 'Tickets';

  @override
  String get navProfile => 'Profile';

  @override
  String get onbTitle1 => 'Discover Events\nNear You';

  @override
  String get onbSub1 =>
      'From underground clubs to rooftop festivals — find what moves you, powered by real-time local intelligence.';

  @override
  String get onbTitle2 => 'Connect With\nYour People';

  @override
  String get onbSub2 =>
      'Follow friends, join communities, and always know who is going where before you commit.';

  @override
  String get onbTitle3 => 'Be the Moment';

  @override
  String get onbSub3 =>
      'Secure tickets in seconds. QR check-in. No stress, no FOMO. Just pure experience.';

  @override
  String get onbContinue => 'Continue';

  @override
  String get getStarted => 'Get Started';

  @override
  String get splashTagline => 'FIND THE ONES. BE THE MOMENT.';

  @override
  String get getDirections => 'Get directions';

  @override
  String get couldNotOpenMaps => 'Could not open a maps app.';

  @override
  String get documentNotFound => 'Document not found';

  @override
  String aboutHappynBody(String version) {
    return 'Find the ones. Be the moment.\n\nDiscover, create, and attend events. Version $version.';
  }

  @override
  String get selectDateOfBirth => 'Select your date of birth';

  @override
  String get deleteAccountWarning =>
      'This is permanent and cannot be undone. Your profile, photo, favourites and notifications will be deleted.';

  @override
  String get deleteAccountRetention =>
      'Past tickets and past events are kept for legal and accounting reasons, but are detached from your profile. Your past events will show “Organizer deleted”.';

  @override
  String get deleteAccountWhatHappens => 'What will happen';

  @override
  String deleteAccountTicketsCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count upcoming tickets will be cancelled',
      one: '1 upcoming ticket will be cancelled',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountEventsCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count upcoming events will be cancelled and their attendees notified',
      one: '1 upcoming event will be cancelled and its attendees notified',
    );
    return '$_temp0';
  }

  @override
  String deleteAccountEventsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count upcoming events with no attendee will be deleted',
      one: '1 upcoming event with no attendee will be deleted',
    );
    return '$_temp0';
  }

  @override
  String get deleteAccountNothingPending =>
      'You have nothing pending — your account can be deleted right away.';

  @override
  String get deleteAccountBlocked =>
      'You have paid ticket sales on an upcoming event. Cancel or refund it first, or contact support@happyn.com.';

  @override
  String get deleteAccountConfirmEmail => 'Type your email address to confirm';

  @override
  String get deleteAccountEmailMismatch =>
      'That doesn\'t match your email address.';

  @override
  String get deleteMyAccount => 'Delete my account';

  @override
  String get accountDeleted => 'Your account has been deleted.';

  @override
  String get deletionFailed =>
      'Deletion failed. Please try again or contact support@happyn.com.';

  @override
  String get feedDiscover => 'Discover';

  @override
  String get feedFollowing => 'Following';

  @override
  String get feedEmpty => 'Nothing here yet';

  @override
  String get feedEmptyBody => 'Be the first to share a moment.';

  @override
  String get feedFollowingEmpty => 'Your feed is quiet';

  @override
  String get feedFollowingEmptyBody => 'Follow people to see their posts here.';

  @override
  String get onNow => 'Happening soon';

  @override
  String get newPost => 'New post';

  @override
  String get postCaptionHint => 'Say something about it...';

  @override
  String get attachEvent => 'Attach an event';

  @override
  String get noEventAttached => 'No event';

  @override
  String get postShare => 'Share';

  @override
  String get postCreated => 'Posted';

  @override
  String get postFailed => 'Could not publish. Please try again.';

  @override
  String get postNeedsContent => 'Add a photo or a few words.';

  @override
  String get postNeedsEvent => 'Choose the event this is about.';

  @override
  String get attachEventRequired => 'Event *';

  @override
  String get chooseEvent => 'Choose an event';

  @override
  String get noAttachableEvents =>
      'You have no event to post about yet. Get a ticket or create an event first.';

  @override
  String get shareMoment => 'Share a moment';

  @override
  String get reportPost => 'Report this post';

  @override
  String get deletePost => 'Delete post';

  @override
  String get deletePostConfirm => 'Delete this post? This cannot be undone.';

  @override
  String get postDeleted => 'Post deleted';

  @override
  String get follow => 'Follow';

  @override
  String get unfollow => 'Following';

  @override
  String get postsCount => 'Posts';

  @override
  String get createEventChoice => 'Event';

  @override
  String get createPostChoice => 'Post';

  @override
  String get createWhat => 'What do you want to create?';

  @override
  String get report => 'Report';

  @override
  String get reportEvent => 'Report this event';

  @override
  String get reportReason => 'Why are you reporting this?';

  @override
  String get reportReasonSpam => 'Spam or repetitive';

  @override
  String get reportReasonInappropriate => 'Inappropriate or offensive';

  @override
  String get reportReasonScam => 'Scam or fraud';

  @override
  String get reportReasonMisleading => 'Misleading information';

  @override
  String get reportReasonOther => 'Something else';

  @override
  String get reportDetailsHint => 'Add details (optional)';

  @override
  String get reportSubmit => 'Send report';

  @override
  String get reportThanks => 'Thanks — our team will review this.';

  @override
  String get reportFailed => 'Could not send the report. Please try again.';

  @override
  String get blockOrganizer => 'Block organizer';

  @override
  String get blockConfirmTitle => 'Block this organizer?';

  @override
  String get blockConfirmBody =>
      'You will no longer see their events. You can unblock them at any time from Settings.';

  @override
  String get block => 'Block';

  @override
  String get unblock => 'Unblock';

  @override
  String get userBlocked => 'Organizer blocked.';

  @override
  String get userUnblocked => 'Organizer unblocked.';

  @override
  String get blockedAccount => 'Blocked account';

  @override
  String get blockedUsersEmpty => 'You haven\'t blocked anyone';

  @override
  String get blockedUsersEmptyBody =>
      'Blocked accounts and their events won\'t appear in your feeds.';
}
