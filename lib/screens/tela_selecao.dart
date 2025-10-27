import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // Importa para usar TapGestureRecognizer

import '../widgets/botao_selecao_perfil.dart';
import 'tela_motorista.dart';
import 'tela_aluno.dart';
import 'tela_sobre_carrossel.dart';
import 'tela_login.dart'; // ⬅️ IMPORTA A TELA DE LOGIN

class TelaSelecao extends StatelessWidget {
  const TelaSelecao({super.key});

  @override
  Widget build(BuildContext context) {
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
        automaticallyImplyLeading: false, // Remove botão de voltar automático
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
                    // Navega para a tela de login antes de decidir o destino
                    Navigator.pushNamed(context, '/login', arguments: {'role': 'motorista'});
                  },
                ),
                const SizedBox(height: 24),
                BotaoSelecaoPerfil(
                  texto: 'ALUNO',
                  icone: Icons.backpack_outlined,
                  corDeFundo: fundoBotaoAmarelo,
                  corDoTexto: corTextoEscuro,
                  aoPressionar: () {
                     // Navega para a tela de login antes de decidir o destino
                    Navigator.pushNamed(context, '/login', arguments: {'role': 'aluno'});
                  },
                ),
                const SizedBox(height: 40), // Espaço antes do link de login

                // 🎯 ADICIONADO: Link para a Tela de Login
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: corBranca, fontSize: 16),
                      children: [
                        const TextSpan(text: 'Já tem uma conta? '),
                        TextSpan(
                          text: 'Faça Login',
                          style: const TextStyle(
                            color: fundoBotaoAmarelo, // Usa a cor amarela para destaque
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              // Navega diretamente para a tela de login
                              Navigator.pushNamed(context, '/login');
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
