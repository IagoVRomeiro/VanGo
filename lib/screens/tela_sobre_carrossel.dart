import 'package:flutter/material.dart';

class TelaSobreCarrossel extends StatelessWidget {
  const TelaSobreCarrossel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = [
      _buildPage(
        context,
        title: 'Bem-vindo ao VanGo!',
        content:
            'Sua plataforma para transporte escolar e universitário com segurança, organização e comunicação em tempo real.',
        gradient: const LinearGradient(
          colors: [Color(0xFF0F0F0F), Color(0xFF1D1D1D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accent: theme.colorScheme.secondary,
        icon: Icons.directions_bus_filled,
        textColor: Colors.white,
      ),
      _buildPage(
        context,
        title: 'Motorista no comando',
        content:
            'Rotas otimizadas, lista de alunos, chat rápido e notificações. Tudo no mesmo painel para dirigir com foco.',
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1F6C), Color(0xFF3C2F8F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        accent: theme.colorScheme.surface,
        icon: Icons.route,
        textColor: Colors.white,
      ),
      _buildPage(
        context,
        title: 'Aluno e responsável tranquilos',
        content:
            'Acompanhe a van em tempo real, veja presença e converse com o motorista. Transparência do embarque ao destino.',
        gradient: const LinearGradient(
          colors: [Color(0xFFB5FF2A), Color(0xFF4A7C0F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        accent: Colors.black,
        icon: Icons.school_outlined,
        textColor: Colors.black,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre o VanGo'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: PageView.builder(
        itemCount: pages.length,
        itemBuilder: (context, index) => pages[index],
      ),
    );
  }

  Widget _buildPage(
    BuildContext context, {
    required String title,
    required String content,
    required LinearGradient gradient,
    required IconData icon,
    required Color accent,
    Color textColor = Colors.white,
  }) {
    return Container(
      decoration: BoxDecoration(gradient: gradient),
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 88,
                width: 88,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.5), width: 2),
                ),
                child: Icon(icon, size: 44, color: accent),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: textColor.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
