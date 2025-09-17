import 'package:flutter/material.dart';

// Este é um COMPONENTE REUTILIZÁVEL.
// Note que ele não tem Scaffold, AppBar ou botão Salvar.
// Ele foi projetado para ser uma "peça" em outras telas.
class EntradaCheckBox extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool?> onChanged; // Função para notificar a mudança

  const EntradaCheckBox({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Retorna apenas o CheckboxListTile, pronto para ser usado.
    return CheckboxListTile(
      title: Text(title),
      secondary: const Icon(Icons.check_box_outline_blank),
      value: value,
      onChanged: onChanged, // Chama a função que foi passada pelo widget pai
      controlAffinity: ListTileControlAffinity.leading, // Coloca a checkbox na frente
    );
  }
}
