// lib/models/van.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// 1. Colocamos o ENUM aqui para que ele seja importado junto com a classe Van.
enum StatusVan {
  disponivel,
  emManutencao,
  emRota,
  indisponivel;

  static StatusVan fromString(String? status) {
    return StatusVan.values.firstWhere(
      (e) => e.name == status,
      orElse: () => StatusVan.indisponivel,
    );
  }
}

class Van {
  // 2. Garantimos que ID, MARCA e MODELO existem.
  final String id;
  final String placa;
  final String marca;
  final String modelo;
  final String cor;
  final int ano;
  final int capacidade;
  final bool documentacaoValida;
  final StatusVan status;
  final String motoristaId;
  final String? fotoUrl;
  final Timestamp? criadoEm;

  Van({
    // Adicionamos os campos que faltavam ao construtor
    required this.id,
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.ano,
    required this.capacidade,
    required this.cor,
    required this.documentacaoValida,
    required this.status,
    required this.motoristaId,
    this.fotoUrl,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'placa': placa,
      'marca': marca,
      'modelo': modelo,
      'ano': ano,
      'capacidade': capacidade,
      'cor': cor,
      'documentacaoValida': documentacaoValida,
      'status': status.name,
      'motoristaId': motoristaId,
      'fotoUrl': fotoUrl,
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
    };
  }

  factory Van.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) throw Exception("Documento da van não encontrado ou está vazio.");

    return Van(
      id: snapshot.id, // O ID do documento
      placa: data['placa'] ?? '',
      marca: data['marca'] ?? '',
      modelo: data['modelo'] ?? '',
      ano: data['ano'] ?? DateTime.now().year,
      capacidade: data['capacidade'] ?? 0,
      cor: data['cor'] ?? '',
      documentacaoValida: data['documentacaoValida'] ?? false,
      status: StatusVan.fromString(data['status']),
      motoristaId: data['motoristaId'] ?? '',
      fotoUrl: data['fotoUrl'],
      criadoEm: data['criadoEm'],
    );
  }
}