import 'package:flutter/material.dart';

/// Um widget reutilizável que exibe um grupo de opções de rádio.
///
/// Este componente não tem estado próprio; o seu valor (selecionado)
/// é controlado pela tela que o utiliza.
class GrupoRadio<T> extends StatelessWidget {
  /// O título ou a pergunta a ser exibida acima das opções.
  final String title;

  /// O valor atualmente selecionado no grupo.
  final T groupValue;

  /// A função a ser chamada quando uma nova opção é selecionada.
  final ValueChanged<T?> onChanged;

  /// Um mapa de opções, onde a chave é o valor e o valor é o texto a ser exibido.
  final Map<T, String> options;

  const GrupoRadio({
    super.key,
    required this.title,
    required this.groupValue,
    required this.onChanged,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        // Geramos uma lista de RadioListTile a partir do mapa de opções
        ...options.entries.map((entry) {
          return RadioListTile<T>(
            title: Text(entry.value),
            value: entry.key,
            groupValue: groupValue,
            onChanged: onChanged,
            contentPadding: EdgeInsets.zero, // Remove o espaçamento extra
          );
        }).toList(),
      ],
    );
  }
}

