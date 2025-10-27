import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../widgets/botao_selecao_perfil.dart';
import 'tela_motorista.dart';
// import 'tela_busca_motorista.dart'; // ⬅️ Este import não é mais necessário aqui
import 'tela_aluno.dart'; // ⬅️ 1. ADICIONAR ESTE IMPORT
import 'tela_sobre_carrossel.dart';
import 'tela_login.dart';

class TelaSelecao extends StatelessWidget {
  const TelaSelecao({super.key});

  @override
  Widget build(BuildContext context) {
    // 
    // O código anterior estava em falta destas definições de constantes
    // 
    const Color corVermelhaPrincipal = Color(0xFFE53935);
    const Color fundoBotaoEscuro = Color(0xFF2d2d2d);
    const Color fundoBotaoAmarelo = Color(0xFFFFB300);
    const Color corBranca = Colors.white;
    const Color corTextoEscuro = Color(0xFF2d2d2d);

    return Scaffold(
      backgroundColor: corVermelhaPrincipal,
      appBar: AppBar(
        backgroundColor: corVermelhaPrincipal,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: corBranca),
            tooltip: 'Sobre o App',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TelaSobreCarrossel()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 120,
                  child: Image.asset(
                    'assets/images/vgo_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 80),
                BotaoSelecaoPerfil(
                  texto: 'MOTORISTA',
                  icone: Icons.drive_eta_outlined,
                  corDeFundo: fundoBotaoEscuro,
                  corDoTexto: corBranca,
                  aoPressionar: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const TelaMotorista(initialIndex: 0),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                BotaoSelecaoPerfil(
                  texto: 'ALUNO',
                  icone: Icons.backpack_outlined,
                  corDeFundo: fundoBotaoAmarelo,
                  corDoTexto: corTextoEscuro,
                  aoPressionar: () {
                    // 🔹 CORRIGIDO: Navega para a tela de Aluno
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TelaAluno(), // ⬅️ 2. MUDADO AQUI
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40), // Espaço antes do link de login
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: corBranca, fontSize: 16),
                      children: [
                        const TextSpan(text: 'Já tem uma conta? '),
                        TextSpan(
                          text: 'Faça Login',
                          style: const TextStyle(
                            color: fundoBotaoAmarelo, // Destaque
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              // Navega diretamente para a tela de login
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const TelaLogin()),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

