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
  final String placa;
  final String modelo;
  final String marca;
  final String cor;
  final int ano;
  final int capacidade;
  final bool documentacaoValida;
  final StatusVan status;
  final String motoristaId;
  final String? fotoUrl;
  final Timestamp? criadoEm;

  Van({
    required this.placa,
    required this.modelo,
    required this.marca,
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
      'modelo': modelo,
      'marca': marca,
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
      placa: snapshot.id,
      modelo: data['modelo'] ?? '',
      marca: data['marca'] ?? '',
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
