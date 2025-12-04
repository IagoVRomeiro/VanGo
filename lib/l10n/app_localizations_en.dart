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
  String get darkTheme => 'Dark theme';

  @override
  String get appLanguage => 'App language';

  @override
  String get languagePortuguese => 'Portuguese';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'French';

  @override
  String get navMap => 'Map';

  @override
  String get navChat => 'Chat';

  @override
  String get navSearch => 'Search';

  @override
  String get navProfile => 'Profile';

  @override
  String get alunoMapTitle => 'Student Map';

  @override
  String get chatMotoristaTitle => 'Chat with Driver';

  @override
  String get procurarMotoristaTitle => 'Find Driver';

  @override
  String get meuPerfilTitle => 'My Profile';

  @override
  String get welcomeTitle => 'Welcome to VanGo!';

  @override
  String get welcomeSubtitle => 'Your easy transport solution.';

  @override
  String get motoristaCardTitle => 'DRIVER';

  @override
  String get motoristaCardDesc => 'Manage your routes and students.';

  @override
  String get alunoCardTitle => 'STUDENT';

  @override
  String get alunoCardDesc => 'Track your van and chat with the driver.';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get loginLink => 'Log in';

  @override
  String get aboutApp => 'About the App';

  @override
  String get loginTitle => 'Login';

  @override
  String get emailHint => 'Your email';

  @override
  String get passwordHint => 'Your password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get enterButton => 'ENTER';

  @override
  String get noAccount => 'Don’t have an account? ';

  @override
  String get signupLink => 'Sign up';

  @override
  String get errorUnknownRole => 'Could not determine user type.';

  @override
  String get errorUserDataMissing => 'User data not found.';

  @override
  String get authErrorFallback => 'An authentication error occurred.';

  @override
  String unexpectedError(Object error) {
    return 'An unexpected error occurred: $error';
  }

  @override
  String get loadingRoutes => 'Loading routes...';

  @override
  String get noRoutesLinked => 'No routes linked at the moment.';

  @override
  String routeLabel(Object nome) {
    return 'Route: $nome';
  }

  @override
  String get destinationCache => 'Destination (cache)';

  @override
  String stopLabel(Object index) {
    return 'Stop $index';
  }

  @override
  String get searchNameHint => 'Search by name...';

  @override
  String get loadingColleges => 'Loading colleges...';

  @override
  String get filterByCollege => 'Filter by college';

  @override
  String get allColleges => 'All colleges';

  @override
  String get noColleges =>
      'No colleges registered. Create routes to unlock filters.';

  @override
  String get noDriversFound => 'No drivers found.';

  @override
  String get currentDriverTitle => 'Your current driver';

  @override
  String ratingLabel(Object nota) {
    return 'Rating: $nota ★';
  }

  @override
  String get loginToSearch => 'Log in to search for drivers.';

  @override
  String get loginButton => 'Log in';

  @override
  String logoutError(Object erro) {
    return 'Error while signing out: $erro';
  }

  @override
  String get avaliacoesTitle => 'Reviews';

  @override
  String errorLoadingRatings(Object erro) {
    return 'Error loading reviews: $erro';
  }

  @override
  String get noRatings => 'No reviews recorded for this driver.';

  @override
  String studentLabel(Object id) {
    return 'Student: $id';
  }

  @override
  String get studentUnknown => 'Student not identified';

  @override
  String get chatInquiryDriver =>
      'Chatting with a student not yet linked. Only link when you want to add them to your route.';

  @override
  String get chatInquiryStudent =>
      'You are not linked to this driver yet, but you can chat normally.';

  @override
  String get chatHint => 'Type a message...';

  @override
  String get functionsMissing =>
      'Server function not found. Check your Cloud Functions deployment.';

  @override
  String get unlinkSuccess => 'Unlinked successfully.';

  @override
  String unlinkError(Object erro) {
    return 'Error unlinking: $erro';
  }
}
