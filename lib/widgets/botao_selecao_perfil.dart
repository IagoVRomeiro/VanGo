import 'package:flutter/material.dart';

class BotaoSelecaoPerfil extends StatelessWidget {
  final String texto;
  final IconData icone;
  final Color corDeFundo;
  final Color corDoTexto;
  final VoidCallback aoPressionar;

  const BotaoSelecaoPerfil({
    super.key,
    required this.texto,
    required this.icone,
    required this.corDeFundo,
    required this.corDoTexto,
    required this.aoPressionar,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: aoPressionar,
      style: ElevatedButton.styleFrom(
        backgroundColor: corDeFundo,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 5,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, color: corDoTexto, size: 24),
          const SizedBox(width: 16),
          Text(
            texto,
            style: TextStyle(
              color: corDoTexto,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}