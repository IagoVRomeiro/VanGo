import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusPresenca { presente, ausente, embarcou }

class Aluno {
  final String id;
  final String nome;
  final String endereco;
  final GeoPoint localizacao;
  final StatusPresenca statusPresenca;
  final String? motoristaId;
  final Timestamp? criadoEm;

  Aluno({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.localizacao,
    required this.statusPresenca,
    this.motoristaId,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'endereco': endereco,
      'localizacao': localizacao,
      'statusPresenca': statusPresenca.name,
      'motoristaId': motoristaId,
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
    };
  }

  factory Aluno.fromMap(String id, Map<String, dynamic> data) {
    return Aluno(
      id: id,
      nome: data['nome'] ?? 'Nome não informado',
      endereco: data['endereco'] ?? '',
      localizacao: (data['localizacao'] as GeoPoint?) ?? GeoPoint(0, 0),
      statusPresenca: StatusPresenca.values.firstWhere(
        (e) => e.name == data['statusPresenca'],
        orElse: () => StatusPresenca.ausente,
      ),
      motoristaId: data['motoristaId'],
      criadoEm: data['criadoEm'],
    );
  }
}