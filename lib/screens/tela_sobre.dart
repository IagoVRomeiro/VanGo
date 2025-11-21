import 'package:flutter/material.dart';

class TelaSobre extends StatelessWidget {
  const TelaSobre({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre o VanGo'),
        backgroundColor: const Color(0xFFE53935), // Cor principal do app
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            '''Bem-vindo ao VanGo! 🚐

Um aplicativo criado para facilitar a comunicação e a organização 
entre motoristas de vans e alunos.

Selecione seu perfil na tela inicial e comece agora mesmo!''',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, height: 1.5),
          ),
        ),
      ),
    );
  }
}
