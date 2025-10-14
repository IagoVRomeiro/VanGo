// lib/widgets/acao_flutuante_item.dart

import 'package:flutter/material.dart';

// Esta classe representa um único item no nosso menu flutuante.
class AcaoFlutuanteItem {
  final String valor; // Um identificador único, ex: 'criar_rota'
  final String texto; // O texto que o usuário vê, ex: 'Criar rota'
  final IconData icone; // O ícone ao lado do texto

  const AcaoFlutuanteItem({
    required this.valor,
    required this.texto,
    required this.icone,
  });
}