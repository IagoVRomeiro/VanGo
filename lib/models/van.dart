// lib/models/van.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String id;
  final String placa;
  final String marca;
  final String modelo;
  final String cor;
  final int ano;
  final int capacidade;
  final StatusVan status;
  final String motoristaId; // <-- Ótimo, FK para o motorista
  final Timestamp? criadoEm;

  // 🔹 RENOMEADO: 'fotoUrl' para 'vanFotoUrl'
  // Para diferenciar da 'fotoUrl' do usuário na classe 'Usuario'.
  final String? vanFotoUrl;

  Van({
    required this.id,
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.ano,
    required this.capacidade,
    required this.cor,
    required this.status,
    required this.motoristaId,
    this.vanFotoUrl, 
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
      'status': status.name,
      'motoristaId': motoristaId,
      'vanFotoUrl': vanFotoUrl, 
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
    };
  }

  factory Van.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) throw Exception("Documento da van não encontrado ou está vazio.");

    return Van(
      id: snapshot.id,
      placa: data['placa'] ?? '',
      marca: data['marca'] ?? '',
      modelo: data['modelo'] ?? '',
      ano: data['ano'] ?? DateTime.now().year,
      capacidade: data['capacidade'] ?? 0,
      cor: data['cor'] ?? '',
      status: StatusVan.fromString(data['status']),
      motoristaId: data['motoristaId'] ?? '',
      vanFotoUrl: data['vanFotoUrl'],
      criadoEm: data['criadoEm'],
    );
  }
}