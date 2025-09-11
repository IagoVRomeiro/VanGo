import 'package:flutter/material.dart';
// ADICIONE ESTE IMPORT PARA A NOVA TELA DE MAPA
import 'package:interface_app2/screens/mapa_motorista_screen.dart';

class SelectionScreen extends StatelessWidget {
  const SelectionScreen({super.key});

  // ... (código das cores continua o mesmo)
  static const Color corFundo = Color(0xFFD32F2F);
  static const Color corBotaoMotorista = Color(0xFF333333);
  static const Color corBotaoAluno = Color(0xFFFFC107);


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corFundo,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ... (código da logo e do espaço continua o mesmo)
                Image.asset(
                  'assets/logo.png',
                  height: 150,
                ),
                const SizedBox(height: 80),

                // BOTÃO MOTORISTA
                ElevatedButton.icon(
                  icon: const Icon(Icons.directions_car, size: 28),
                  label: const Text(
                    'MOTORISTA',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  // ALTERE A FUNÇÃO onPressed AQUI
                  onPressed: () {
                    // Navega para a tela do mapa
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MapaMotoristaScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: corBotaoMotorista,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                ),
                const SizedBox(height: 24),

                // ... (código do botão ALUNO continua o mesmo)
                ElevatedButton.icon(
                  icon: const Icon(Icons.school, size: 28),
                  label: const Text(
                    'ALUNO',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    print('Botão ALUNO pressionado!');
                    // TODO: Navegar para a tela de login do aluno
                  },
                   style: ElevatedButton.styleFrom(
                    backgroundColor: corBotaoAluno,
                    foregroundColor: corBotaoMotorista,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
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
