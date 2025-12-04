import 'package:vango/services/functions_service.dart';

/// Serviço simples para encapsular chamadas relacionadas a emails.
/// Atualmente delega para a Cloud Function `sendWelcomeEmail`, mas
/// falhas não devem impedir o fluxo principal de cadastro.
class EmailService {
  EmailService._();

  static final EmailService instance = EmailService._();

  factory EmailService() => instance;

  /// Envia um email de boas-vindas ao usuário recém-cadastrado.
  /// Caso a função HTTPS não esteja disponível, o erro é capturado
  /// para evitar quebrar o processo de cadastro.
  Future<void> sendWelcomeEmail(String email, String nome) async {
    try {
      await FunctionsService.instance.call<void>(
        'sendWelcomeEmail',
        data: <String, dynamic>{'email': email, 'nome': nome},
      );
    } catch (e) {
      // No momento o envio de email é apenas um extra, então logamos o erro.
      // Use um logger se quiser rastrear melhor no futuro.
      // ignore: avoid_print
      print('Falha ao enviar email de boas-vindas: $e');
    }
  }
}
