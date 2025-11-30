import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'tela_aluno.dart';
import 'tela_cadastro.dart';
import 'tela_motorista.dart';
import 'tela_recuperar_senha.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );

      final user = cred.user;
      if (user != null && mounted) {
        // Obter o token FCM
        final fcmToken = await FirebaseMessaging.instance.getToken();

        // Salvar o token no documento do usuário
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'fcmToken': fcmToken},
          SetOptions(merge: true),
        );
        
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        Navigator.pop(context); // fecha o progress dialog

        if (userDoc.exists) {
          final role = userDoc.data()?['role'];

          if (role == 'motorista') {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const TelaMotorista()),
              (route) => false,
            );
          } else if (role == 'aluno') {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => TelaAluno()),
              (route) => false,
            );
          } else {
            _mostrarErro('Não foi possível determinar o tipo de usuário.');
          }
        } else {
          _mostrarErro('Dados do usuário não encontrados.');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);
      _mostrarErro(e.message ?? 'Ocorreu um erro de autenticação.');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _mostrarErro('Ocorreu um erro inesperado: $e');
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  SizedBox(
                    height: 100,
                    child: Image.asset('assets/iconSemFundo.png'),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Login', 
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _campoTexto(
                    controller: _emailController,
                    dica: 'Seu e-mail',
                    icone: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _campoTexto(
                    controller: _senhaController,
                    dica: 'Sua senha',
                    icone: Icons.lock_outline,
                    isPassword: true,
                  ),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: GestureDetector(
                        onTap: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TelaRecuperarSenha()),
                          );
                        },
                        child: Text(
                          'Esqueceu a senha?',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: _botaoPrincipal(
                      texto: 'ENTRAR',
                      aoPressionar: _login,
                    ),
                  ),
                  const SizedBox(height: 30),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        const TextSpan(text: 'Não tem uma conta? '),
                        TextSpan(
                          text: 'Cadastre-se',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const TelaCadastro()),
                              );
                            },
                        ),
                      ],
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
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? !_senhaVisivel : false,
      style: theme.textTheme.bodyLarge,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: dica,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 20, right: 15),
          child: Icon(icone, color: theme.colorScheme.onSurfaceVariant, size: 22),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _senhaVisivel ? Icons.visibility_off : Icons.visibility, 
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)
                ),
                onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
              )
            : null,
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
    return ElevatedButton(
      onPressed: aoPressionar,
      child: Text(
        texto, 
        style: const TextStyle(
          fontSize: 16, 
          fontWeight: FontWeight.bold, 
          letterSpacing: 1.1
        ),
      ),
    );
  }
}
