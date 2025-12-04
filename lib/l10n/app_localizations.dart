import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('pt')
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get darkTheme;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePortuguese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @alunoMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Student Map'**
  String get alunoMapTitle;

  /// No description provided for @chatMotoristaTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat with Driver'**
  String get chatMotoristaTitle;

  /// No description provided for @procurarMotoristaTitle.
  ///
  /// In en, this message translates to:
  /// **'Find Driver'**
  String get procurarMotoristaTitle;

  /// No description provided for @meuPerfilTitle.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get meuPerfilTitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to VanGo!'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your easy transport solution.'**
  String get welcomeSubtitle;

  /// No description provided for @motoristaCardTitle.
  ///
  /// In en, this message translates to:
  /// **'DRIVER'**
  String get motoristaCardTitle;

  /// No description provided for @motoristaCardDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your routes and students.'**
  String get motoristaCardDesc;

  /// No description provided for @alunoCardTitle.
  ///
  /// In en, this message translates to:
  /// **'STUDENT'**
  String get alunoCardTitle;

  /// No description provided for @alunoCardDesc.
  ///
  /// In en, this message translates to:
  /// **'Track your van and chat with the driver.'**
  String get alunoCardDesc;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @loginLink.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginLink;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About the App'**
  String get aboutApp;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Your email'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get passwordHint;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @enterButton.
  ///
  /// In en, this message translates to:
  /// **'ENTER'**
  String get enterButton;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don’t have an account? '**
  String get noAccount;

  /// No description provided for @signupLink.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signupLink;

  /// No description provided for @errorUnknownRole.
  ///
  /// In en, this message translates to:
  /// **'Could not determine user type.'**
  String get errorUnknownRole;

  /// No description provided for @errorUserDataMissing.
  ///
  /// In en, this message translates to:
  /// **'User data not found.'**
  String get errorUserDataMissing;

  /// No description provided for @authErrorFallback.
  ///
  /// In en, this message translates to:
  /// **'An authentication error occurred.'**
  String get authErrorFallback;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred: {error}'**
  String unexpectedError(Object error);

  /// No description provided for @loadingRoutes.
  ///
  /// In en, this message translates to:
  /// **'Loading routes...'**
  String get loadingRoutes;

  /// No description provided for @noRoutesLinked.
  ///
  /// In en, this message translates to:
  /// **'No routes linked at the moment.'**
  String get noRoutesLinked;

  /// No description provided for @routeLabel.
  ///
  /// In en, this message translates to:
  /// **'Route: {nome}'**
  String routeLabel(Object nome);

  /// No description provided for @destinationCache.
  ///
  /// In en, this message translates to:
  /// **'Destination (cache)'**
  String get destinationCache;

  /// No description provided for @stopLabel.
  ///
  /// In en, this message translates to:
  /// **'Stop {index}'**
  String stopLabel(Object index);

  /// No description provided for @searchNameHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name...'**
  String get searchNameHint;

  /// No description provided for @loadingColleges.
  ///
  /// In en, this message translates to:
  /// **'Loading colleges...'**
  String get loadingColleges;

  /// No description provided for @filterByCollege.
  ///
  /// In en, this message translates to:
  /// **'Filter by college'**
  String get filterByCollege;

  /// No description provided for @allColleges.
  ///
  /// In en, this message translates to:
  /// **'All colleges'**
  String get allColleges;

  /// No description provided for @noColleges.
  ///
  /// In en, this message translates to:
  /// **'No colleges registered. Create routes to unlock filters.'**
  String get noColleges;

  /// No description provided for @noDriversFound.
  ///
  /// In en, this message translates to:
  /// **'No drivers found.'**
  String get noDriversFound;

  /// No description provided for @currentDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Your current driver'**
  String get currentDriverTitle;

  /// No description provided for @ratingLabel.
  ///
  /// In en, this message translates to:
  /// **'Rating: {nota} ★'**
  String ratingLabel(Object nota);

  /// No description provided for @loginToSearch.
  ///
  /// In en, this message translates to:
  /// **'Log in to search for drivers.'**
  String get loginToSearch;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginButton;

  /// No description provided for @logoutError.
  ///
  /// In en, this message translates to:
  /// **'Error while signing out: {erro}'**
  String logoutError(Object erro);

  /// No description provided for @avaliacoesTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get avaliacoesTitle;

  /// No description provided for @errorLoadingRatings.
  ///
  /// In en, this message translates to:
  /// **'Error loading reviews: {erro}'**
  String errorLoadingRatings(Object erro);

  /// No description provided for @noRatings.
  ///
  /// In en, this message translates to:
  /// **'No reviews recorded for this driver.'**
  String get noRatings;

  /// No description provided for @studentLabel.
  ///
  /// In en, this message translates to:
  /// **'Student: {id}'**
  String studentLabel(Object id);

  /// No description provided for @studentUnknown.
  ///
  /// In en, this message translates to:
  /// **'Student not identified'**
  String get studentUnknown;

  /// No description provided for @chatInquiryDriver.
  ///
  /// In en, this message translates to:
  /// **'Chatting with a student not yet linked. Only link when you want to add them to your route.'**
  String get chatInquiryDriver;

  /// No description provided for @chatInquiryStudent.
  ///
  /// In en, this message translates to:
  /// **'You are not linked to this driver yet, but you can chat normally.'**
  String get chatInquiryStudent;

  /// No description provided for @chatHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatHint;

  /// No description provided for @functionsMissing.
  ///
  /// In en, this message translates to:
  /// **'Server function not found. Check your Cloud Functions deployment.'**
  String get functionsMissing;

  /// No description provided for @unlinkSuccess.
  ///
  /// In en, this message translates to:
  /// **'Unlinked successfully.'**
  String get unlinkSuccess;

  /// No description provided for @unlinkError.
  ///
  /// In en, this message translates to:
  /// **'Error unlinking: {erro}'**
  String unlinkError(Object erro);
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
      <String>['en', 'fr', 'pt'].contains(locale.languageCode);

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
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
