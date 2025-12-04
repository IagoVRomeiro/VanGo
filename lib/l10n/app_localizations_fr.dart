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
  String get darkTheme => 'Thème sombre';

  @override
  String get appLanguage => 'Langue de l\'application';

  @override
  String get languagePortuguese => 'Portugais';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageFrench => 'Français';

  @override
  String get navMap => 'Carte';

  @override
  String get navChat => 'Chat';

  @override
  String get navSearch => 'Rechercher';

  @override
  String get navProfile => 'Profil';

  @override
  String get alunoMapTitle => 'Carte de l\'étudiant';

  @override
  String get chatMotoristaTitle => 'Discussion avec le chauffeur';

  @override
  String get procurarMotoristaTitle => 'Trouver un chauffeur';

  @override
  String get meuPerfilTitle => 'Mon profil';

  @override
  String get welcomeTitle => 'Bienvenue sur VanGo !';

  @override
  String get welcomeSubtitle => 'Votre solution de transport facile.';

  @override
  String get motoristaCardTitle => 'CHAUFFEUR';

  @override
  String get motoristaCardDesc => 'Gérez vos trajets et vos étudiants.';

  @override
  String get alunoCardTitle => 'ÉTUDIANT';

  @override
  String get alunoCardDesc => 'Suivez votre van et discutez avec le chauffeur.';

  @override
  String get alreadyHaveAccount => 'Vous avez déjà un compte ? ';

  @override
  String get loginLink => 'Connectez-vous';

  @override
  String get aboutApp => 'À propos de l\'app';

  @override
  String get loginTitle => 'Connexion';

  @override
  String get emailHint => 'Votre e-mail';

  @override
  String get passwordHint => 'Votre mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get enterButton => 'ENTRER';

  @override
  String get noAccount => 'Vous n\'avez pas de compte ? ';

  @override
  String get signupLink => 'Inscrivez-vous';

  @override
  String get errorUnknownRole =>
      'Impossible de déterminer le type d\'utilisateur.';

  @override
  String get errorUserDataMissing => 'Données utilisateur introuvables.';

  @override
  String get authErrorFallback =>
      'Une erreur d\'authentification est survenue.';

  @override
  String unexpectedError(Object error) {
    return 'Une erreur imprévue s\'est produite : $error';
  }

  @override
  String get loadingRoutes => 'Chargement des trajets...';

  @override
  String get noRoutesLinked => 'Aucun trajet lié pour le moment.';

  @override
  String routeLabel(Object nome) {
    return 'Trajet : $nome';
  }

  @override
  String get destinationCache => 'Destination (cache)';

  @override
  String stopLabel(Object index) {
    return 'Arrêt $index';
  }

  @override
  String get searchNameHint => 'Rechercher par nom...';

  @override
  String get loadingColleges => 'Chargement des établissements...';

  @override
  String get filterByCollege => 'Filtrer par établissement';

  @override
  String get allColleges => 'Tous les établissements';

  @override
  String get noColleges =>
      'Aucun établissement enregistré. Créez des trajets pour activer les filtres.';

  @override
  String get noDriversFound => 'Aucun chauffeur trouvé.';

  @override
  String get currentDriverTitle => 'Votre chauffeur actuel';

  @override
  String ratingLabel(Object nota) {
    return 'Note : $nota ★';
  }

  @override
  String get loginToSearch => 'Connectez-vous pour chercher des chauffeurs.';

  @override
  String get loginButton => 'Connexion';

  @override
  String logoutError(Object erro) {
    return 'Erreur lors de la déconnexion : $erro';
  }

  @override
  String get avaliacoesTitle => 'Avis';

  @override
  String errorLoadingRatings(Object erro) {
    return 'Erreur lors du chargement des avis : $erro';
  }

  @override
  String get noRatings => 'Aucun avis enregistré pour ce chauffeur.';

  @override
  String studentLabel(Object id) {
    return 'Étudiant : $id';
  }

  @override
  String get studentUnknown => 'Étudiant non identifié';

  @override
  String get chatInquiryDriver =>
      'Vous discutez avec un étudiant non encore lié. Liez uniquement si vous souhaitez l\'ajouter à votre trajet.';

  @override
  String get chatInquiryStudent =>
      'Vous n\'êtes pas encore lié à ce chauffeur, mais vous pouvez discuter normalement.';

  @override
  String get chatHint => 'Écrire un message...';

  @override
  String get functionsMissing =>
      'Fonction serveur introuvable. Vérifiez le déploiement des Cloud Functions.';

  @override
  String get unlinkSuccess => 'Déliaison effectuée avec succès.';

  @override
  String unlinkError(Object erro) {
    return 'Erreur lors de la déliaison : $erro';
  }
}
