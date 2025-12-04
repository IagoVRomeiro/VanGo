import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TelaRecuperarSenha extends StatefulWidget {
  const TelaRecuperarSenha({super.key});

  @override
  State<TelaRecuperarSenha> createState() => _TelaRecuperarSenhaState();
}

class _TelaRecuperarSenhaState extends State<TelaRecuperarSenha> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _enviarEmailDeRecuperacao() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    // Mostra o loading na tela
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context); // Fecha o progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Um link de recuperação foi enviado para ${_emailController.text.trim()}.'),
            backgroundColor: Colors.green,
          ),
        );
        // Retorna para a tela de login
        Navigator.pop(context); 
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context); // Fecha o progress dialog
      
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage = 'Não há usuário cadastrado com este e-mail.';
      } else {
        errorMessage = e.message ?? 'Ocorreu um erro ao enviar o e-mail.';
      }
      _mostrarErro(errorMessage);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _mostrarErro('Ocorreu um erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Recuperar Senha', style: TextStyle(color: theme.appBarTheme.foregroundColor)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Esqueceu a senha?',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Informe o e-mail cadastrado para receber o link de redefinição.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  _campoTexto(
                    controller: _emailController,
                    dica: 'Seu e-mail',
                    icone: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: _botaoPrincipal(
                      texto: _isLoading ? 'ENVIANDO...' : 'ENVIAR LINK',
                      aoPressionar: _isLoading ? () {} : _enviarEmailDeRecuperacao,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String dica,
    required IconData icone,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      style: TextStyle(color: theme.colorScheme.onSurface),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        hintText: dica,
        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 20, right: 15),
          child: Icon(icone, color: theme.colorScheme.onSurface, size: 22),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Campo obrigatório';
        if (keyboardType == TextInputType.emailAddress && !v.contains('@')) return 'E-mail inválido';
        return null;
      },
    );
  }

  Widget _botaoPrincipal({
    required String texto,
    required VoidCallback aoPressionar,
  }) {
    final theme = Theme.of(context);
    return ElevatedButton(
      onPressed: aoPressionar,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 5,
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
