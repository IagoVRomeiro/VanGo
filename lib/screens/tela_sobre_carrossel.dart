import 'package:flutter/material.dart';

class TelaSobreCarrossel extends StatelessWidget {
  const TelaSobreCarrossel({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista de páginas (widgets) para o carrossel
    final List<Widget> pages = [
      _buildPage(
        context,
        title: 'Bem-vindo ao VanGo! 🚐',
        content:
            'A plataforma completa para gerenciar o transporte escolar e universitário. Mais segurança, organização e comunicação em tempo real.',
        color: const Color(0xFFE53935), // Cor principal do Motorista
        icon: Icons.directions_bus,
        textColor: Colors.white,
      ),
      _buildPage(
        context,
        title: 'Para o Motorista: Rota e Controle',
        content:
            'Gerencie suas vans, cadastre rotas otimizadas e mantenha um canal de comunicação direto com os responsáveis. Foque na direção, nós cuidamos da organização.',
        color: const Color(0xFF2d2d2d), // Fundo escuro
        icon: Icons.person_pin,
        textColor: Colors.white,
      ),
      _buildPage(
        context,
        title: 'Para o Aluno/Responsável: Paz de Espírito',
        content:
            'Acompanhe a van em tempo real, saiba o status de presença e tenha acesso rápido ao perfil do motorista e ao chat. Total segurança e transparência.',
        color: const Color(0xFFFFB300), // Cor secundária do Aluno
        icon: Icons.school,
        textColor: const Color(0xFF2d2d2d),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre o VanGo'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        itemCount: pages.length,
        itemBuilder: (context, index) {
          return pages[index];
        },
      ),
    );
  }

  Widget _buildPage(
    BuildContext context, {
    required String title,
    required String content,
    required Color color,
    required IconData icon,
    Color textColor = Colors.white,
  }) {
    return Container(
      color: color,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: textColor,
          ),
          const SizedBox(height: 30),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                height: 1.5,
                color: textColor.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
