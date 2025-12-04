// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get darkTheme => 'Tema escuro';

  @override
  String get appLanguage => 'Idioma do aplicativo';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get languageEnglish => 'Inglês';

  @override
  String get languageFrench => 'Francês';

  @override
  String get navMap => 'Mapa';

  @override
  String get navChat => 'Chat';

  @override
  String get navSearch => 'Procurar';

  @override
  String get navProfile => 'Perfil';

  @override
  String get alunoMapTitle => 'Mapa do Aluno';

  @override
  String get chatMotoristaTitle => 'Chat com Motorista';

  @override
  String get procurarMotoristaTitle => 'Procurar Motorista';

  @override
  String get meuPerfilTitle => 'Meu Perfil';

  @override
  String get welcomeTitle => 'Bem-vindo ao VanGo!';

  @override
  String get welcomeSubtitle => 'Sua solução de transporte fácil.';

  @override
  String get motoristaCardTitle => 'MOTORISTA';

  @override
  String get motoristaCardDesc => 'Gerencie suas rotas e alunos.';

  @override
  String get alunoCardTitle => 'ALUNO';

  @override
  String get alunoCardDesc => 'Acompanhe sua van e converse com o motorista.';

  @override
  String get alreadyHaveAccount => 'Já tem uma conta? ';

  @override
  String get loginLink => 'Faça Login';

  @override
  String get aboutApp => 'Sobre o App';

  @override
  String get loginTitle => 'Login';

  @override
  String get emailHint => 'Seu e-mail';

  @override
  String get passwordHint => 'Sua senha';

  @override
  String get forgotPassword => 'Esqueceu a senha?';

  @override
  String get enterButton => 'ENTRAR';

  @override
  String get noAccount => 'Não tem uma conta? ';

  @override
  String get signupLink => 'Cadastre-se';

  @override
  String get errorUnknownRole =>
      'Não foi possível determinar o tipo de usuário.';

  @override
  String get errorUserDataMissing => 'Dados do usuário não encontrados.';

  @override
  String get authErrorFallback => 'Ocorreu um erro de autenticação.';

  @override
  String unexpectedError(Object error) {
    return 'Ocorreu um erro inesperado: $error';
  }

  @override
  String get loadingRoutes => 'Carregando rotas...';

  @override
  String get noRoutesLinked => 'Sem rotas vinculadas no momento.';

  @override
  String routeLabel(Object nome) {
    return 'Rota: $nome';
  }

  @override
  String get destinationCache => 'Destino (cache)';

  @override
  String stopLabel(Object index) {
    return 'Parada $index';
  }

  @override
  String get searchNameHint => 'Buscar por nome...';

  @override
  String get loadingColleges => 'Carregando faculdades...';

  @override
  String get filterByCollege => 'Filtrar por faculdade';

  @override
  String get allColleges => 'Todas as faculdades';

  @override
  String get noColleges =>
      'Nenhuma faculdade cadastrada. Cadastre rotas para liberar filtros.';

  @override
  String get noDriversFound => 'Nenhum motorista encontrado.';

  @override
  String get currentDriverTitle => 'Seu motorista atual';

  @override
  String ratingLabel(Object nota) {
    return 'Avaliação: $nota ★';
  }

  @override
  String get loginToSearch => 'Faça login para procurar motoristas.';

  @override
  String get loginButton => 'Fazer Login';

  @override
  String logoutError(Object erro) {
    return 'Erro ao sair: $erro';
  }

  @override
  String get avaliacoesTitle => 'Avaliações';

  @override
  String errorLoadingRatings(Object erro) {
    return 'Erro ao carregar avaliações: $erro';
  }

  @override
  String get noRatings => 'Nenhuma avaliação registrada para este motorista.';

  @override
  String studentLabel(Object id) {
    return 'Aluno: $id';
  }

  @override
  String get studentUnknown => 'Aluno não identificado';

  @override
  String get chatInquiryDriver =>
      'Conversando com um aluno ainda não vinculado. Use o vínculo apenas quando desejar adicioná-lo à sua rota.';

  @override
  String get chatInquiryStudent =>
      'Você ainda não está vinculado a este motorista, mas pode conversar normalmente.';

  @override
  String get chatHint => 'Digite uma mensagem...';

  @override
  String get functionsMissing =>
      'Função do servidor não encontrada. Verifique a configuração das Cloud Functions.';

  @override
  String get unlinkSuccess => 'Desvinculado com sucesso.';

  @override
  String unlinkError(Object erro) {
    return 'Erro ao desvincular: $erro';
  }
}
