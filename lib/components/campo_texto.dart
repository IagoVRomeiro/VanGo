import 'package:flutter/material.dart';

// Este é um WIDGET REUTILIZÁVEL.
// Note que ele não tem Scaffold ou AppBar. É apenas a "peça" do campo de texto.
class CampoTexto extends StatelessWidget {
  // Parâmetros que o widget pode receber para ser customizado
  final TextEditingController controller;
  final String labelText;
  final IconData? icon; // Ícone é opcional
  final TextInputType keyboardType;
  final bool enabled;

  // Construtor para inicializar os parâmetros
  const CampoTexto({
    super.key,
    required this.controller,
    required this.labelText,
    this.icon,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // O widget retorna apenas o TextField, pronto para ser usado em qualquer tela
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        // O ícone só aparece se for fornecido
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[200],
      ),
    );
  }
}
