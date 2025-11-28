import 'package:cloud_firestore/cloud_firestore.dart';

// (Enum StatusMotorista aqui...)
enum StatusMotorista {
  disponivel,
  emRota,
  indefinido;

  static StatusMotorista fromString(String? status) {
    return StatusMotorista.values.firstWhere(
      (e) => e.name == status,
      orElse: () => StatusMotorista.indefinido,
    );
  }
}


class Motorista {
  final String id;
  final String cpf;
  final String cnh;
  final double avaliacao;
  final StatusMotorista status;
  final Timestamp? criadoEm;
  final List<String>? alunosIds;
  final List<String>? vansIds;

  Motorista({
    required this.id,
    required this.cpf,
    required this.cnh,
    required this.avaliacao,
    required this.status,
    this.criadoEm,
    this.alunosIds,
    this.vansIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'cpf': cpf,
      'cnh': cnh,
      'avaliacao': avaliacao,
      'status': status.name,
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
      'alunosIds': alunosIds ?? [],
      'vansIds': vansIds ?? [],
    };
  }

  factory Motorista.fromMap(String id, Map<String, dynamic> data) {
    return Motorista(
      id: id,
      cpf: data['cpf'] ?? '',
      cnh: data['cnh'] ?? '',
      avaliacao: (data['avaliacao'] as num?)?.toDouble() ?? 0.0,
      status: StatusMotorista.fromString(data['status']),
      criadoEm: data['criadoEm'],
      alunosIds: List<String>.from(data['alunosIds'] ?? []),
      vansIds: (() {
        final vansIdsData = data['vansIds'];
        if (vansIdsData is List) {
          return List<String>.from(vansIdsData);
        }
        final legacyVanId = data['vanId'] as String?;
        if (legacyVanId != null && legacyVanId.isNotEmpty) {
          return [legacyVanId];
        }
        return <String>[];
      })(),
    );
  }
}
