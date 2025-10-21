import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'tela_aluno.dart'; 
import 'tela_cadastro.dart';
import 'tela_motorista.dart'; 

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
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        Navigator.pop(context); 

        if (userDoc.exists) {
          final role = userDoc.data()?['role'];

          if (role == 'motorista') {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const TelaMotorista()),
              (route) => false, 
            );
          } else if (role == 'aluno') {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const TelaAluno()),
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
    const Color corVermelhaPrincipal = Color(0xFFE53935);
    const Color fundoEscuro = Color(0xFF2d2d2d);
    const Color amareloBotao = Color(0xFFFFB300);
    const Color branco = Colors.white;

    return Scaffold(
      backgroundColor: corVermelhaPrincipal,
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
                    child: Image.asset('assets/images/vgo_logo.png'),
                  ),
                  const SizedBox(height: 40),
                  const Text('Login', style: TextStyle(color: branco, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: _botaoPrincipal(
                      texto: 'ENTRAR',
                      corDeFundo: amareloBotao,
                      corDoTexto: fundoEscuro,
                      aoPressionar: _login,
                    ),
                  ),
                  const SizedBox(height: 30),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(color: branco, fontSize: 15),
                      children: [
                        const TextSpan(text: 'Não tem uma conta? '),
                        TextSpan(
                          text: 'Cadastre-se',
                          style: const TextStyle(color: amareloBotao, fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const TelaCadastro()),
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
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? !_senhaVisivel : false,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF2d2d2d),
        hintText: dica,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 20, right: 15),
          child: Icon(icone, color: Colors.white, size: 22),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility, color: Colors.white.withOpacity(0.7)),
                onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
              )
            : null,
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
    required Color corDeFundo,
    required Color corDoTexto,
    required VoidCallback aoPressionar,
  }) {
    return ElevatedButton(
      onPressed: aoPressionar,
      style: ElevatedButton.styleFrom(
        backgroundColor: corDeFundo,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 5,
      ),
      child: Text(texto, style: TextStyle(color: corDoTexto, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
    );
  }
}