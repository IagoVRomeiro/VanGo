// vango 1.0
import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusPresenca { presente, ausente, embarcou }

class Aluno {
  final String id;
  final GeoPoint localizacao;
  final StatusPresenca statusPresenca;
  final String? motoristaId;
  final Timestamp? criadoEm;

  Aluno({
    required this.id,
    required this.localizacao,
    required this.statusPresenca,
    this.motoristaId,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'localizacao': localizacao,
      'statusPresenca': statusPresenca.name,
      'motoristaId': motoristaId,
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
    };
  }

  factory Aluno.fromMap(String id, Map<String, dynamic> data) {
    return Aluno(
      id: id,
      localizacao: (data['localizacao'] as GeoPoint?) ?? const GeoPoint(0, 0),
      statusPresenca: StatusPresenca.values.firstWhere(
        (e) => e.name == data['statusPresenca'],
        orElse: () => StatusPresenca.ausente,
      ),
      motoristaId: data['motoristaId'],
      criadoEm: data['criadoEm'],
    );
  }
}

