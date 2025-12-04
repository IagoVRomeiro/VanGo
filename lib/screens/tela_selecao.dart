import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:vango/l10n/app_localizations.dart';

import 'tela_cadastro.dart';
import 'tela_sobre_carrossel.dart';
import 'tela_login.dart';

class TelaSelecao extends StatelessWidget {
  const TelaSelecao({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 100,
                  child: Image.asset(
                    'assets/iconSemFundo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  AppLocalizations.of(context)!.welcomeSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 64),

                // Card para Motorista
                _ProfileSelectionCard(
                  title: AppLocalizations.of(context)!.motoristaCardTitle,
                  description: AppLocalizations.of(context)!.motoristaCardDesc,
                  icon: Icons.drive_eta_outlined,
                  color: theme.colorScheme.error,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TelaCadastro(
                          tipoInicial: TipoUsuario.motorista,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                
                // Card para Aluno
                _ProfileSelectionCard(
                  title: AppLocalizations.of(context)!.alunoCardTitle,
                  description: AppLocalizations.of(context)!.alunoCardDesc,
                  icon: Icons.backpack_outlined,
                  color: theme.colorScheme.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TelaCadastro(
                          tipoInicial: TipoUsuario.aluno,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 48),

                // Link para Login
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyLarge,
                      children: [
                        TextSpan(text: AppLocalizations.of(context)!.alreadyHaveAccount),
                        TextSpan(
                          text: AppLocalizations.of(context)!.loginLink,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const TelaLogin()),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TelaSobreCarrossel(),
                      ),
                    );
                  },
                  child: Text(AppLocalizations.of(context)!.aboutApp),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget customizado para os cards de seleção de perfil
class _ProfileSelectionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ProfileSelectionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Card herda o tema global, mas podemos fazer override se necessário
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


