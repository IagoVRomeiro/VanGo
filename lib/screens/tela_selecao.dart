import 'package:flutter/material.dart';
import 'package:vango/widgets/botao_selecao_perfil.dart';
import 'tela_motorista.dart';
import 'tela_aluno.dart';
import 'tela_sobre.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: corBranca),
            tooltip: 'Sobre o App',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TelaSobre()),
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
                    Navigator.pushNamed(context, '/motorista');
                  },
                ),
                const SizedBox(height: 24),
                BotaoSelecaoPerfil(
                  texto: 'ALUNO',
                  icone: Icons.backpack_outlined,
                  corDeFundo: fundoBotaoAmarelo,
                  corDoTexto: corTextoEscuro,
                  aoPressionar: () {
                    Navigator.pushNamed(context, '/aluno');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
