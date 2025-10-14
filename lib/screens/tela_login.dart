// lib/screens/tela_login.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:vango/screens/tela_cadastro.dart';
import 'package:vango/screens/tela_motorista.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});
  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  late final TextEditingController _controladorEmail;
  late final TextEditingController _controladorSenha;
  bool _senhaVisivel = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controladorEmail = TextEditingController();
    _controladorSenha = TextEditingController();
  }

  @override
  void dispose() {
    _controladorEmail.dispose();
    _controladorSenha.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (_controladorEmail.text.isEmpty || _controladorSenha.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha e-mail e senha.'), backgroundColor: Colors.orange),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _controladorEmail.text.trim(),
        password: _controladorSenha.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TelaMotorista()),
        );
      }

    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
      
      String mensagemErro = 'Ocorreu um erro ao fazer login.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        mensagemErro = 'E-mail ou senha incorretos. Tente novamente.';
      } else if (e.code == 'invalid-email') {
        mensagemErro = 'O formato do e-mail é inválido.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagemErro), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color corVermelhaPrincipal = Color(0xFFE53935);
    const Color fundoBotaoEscuro = Color(0xFF2d2d2d);
    const Color fundoBotaoAmarelo = Color(0xFFFFB300);
    const Color corBranca = Colors.white;
    
    return Scaffold(
      backgroundColor: corVermelhaPrincipal,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  // AQUI ESTÁ A CORREÇÃO ✅
                  SizedBox(height: 100, child: Image.asset('assets/images/vgo_logo.png')),
                  const SizedBox(height: 60),
                  _construirCampoDeTexto(
                    controlador: _controladorEmail,
                    dica: 'Email',
                    icone: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),
                  _construirCampoDeTexto(
                    controlador: _controladorSenha,
                    dica: 'Senha',
                    icone: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Esqueceu a senha?',
                      style: TextStyle(color: corBranca.withOpacity(0.9), fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _construirBotaoPrincipal(
                    texto: 'ENTRAR',
                    corDeFundo: fundoBotaoAmarelo,
                    corDoTexto: fundoBotaoEscuro,
                    aoPressionar: _fazerLogin,
                  ),
                  const SizedBox(height: 24),
                  const Center(child: Text('ou', style: TextStyle(color: corBranca, fontSize: 16))),
                  const SizedBox(height: 24),
                  _construirBotaoPrincipal(
                    texto: 'ENTRAR COM GOOGLE',
                    corDeFundo: fundoBotaoEscuro,
                    corDoTexto: corBranca,
                    icone: FontAwesomeIcons.google,
                    aoPressionar: () {},
                  ),
                  const SizedBox(height: 60),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(color: corBranca, fontSize: 15),
                      children: [
                        const TextSpan(text: 'Não tem uma conta? '),
                        TextSpan(
                          text: 'Cadastre-se',
                          style: const TextStyle(color: fundoBotaoAmarelo, fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()..onTap = () {
                            Navigator.push(
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

  // Seus métodos _construirCampoDeTexto e _construirBotaoPrincipal permanecem os mesmos...
  Widget _construirCampoDeTexto({
    required TextEditingController controlador,
    required String dica,
    required IconData icone,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d2d),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 3))],
      ),
      child: TextField(
        controller: controlador,
        obscureText: isPassword ? !_senhaVisivel : false,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          hintText: dica,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: InputBorder.none,
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 20, right: 15), child: Icon(icone, color: Colors.white, size: 22)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility, color: Colors.white.withOpacity(0.7)),
                  onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                )
              : null,
        ),
      ),
    );
  }

  Widget _construirBotaoPrincipal({
    required String texto,
    required Color corDeFundo,
    required Color corDoTexto,
    required VoidCallback aoPressionar,
    IconData? icone,
  }) {
    return ElevatedButton(
      onPressed: aoPressionar,
      style: ElevatedButton.styleFrom(
        backgroundColor: corDeFundo,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 5,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icone != null) ...[
            FaIcon(icone, color: corDoTexto, size: 20),
            const SizedBox(width: 12),
          ],
          Text(
            texto,
            style: TextStyle(color: corDoTexto, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
        ],
      ),
    );
  }
}