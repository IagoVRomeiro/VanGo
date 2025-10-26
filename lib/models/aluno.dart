import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusPresenca { presente, ausente, embarcou, desembarcou, desconhecido }

class Aluno {
  final String id;
  final String nome;
  final String endereco;
  final GeoPoint localizacao; 
  final String? faculdade;
  final String horarioEntrada;
  final String horarioSaida;
  final StatusPresenca statusPresenca;
  final String? motoristaId;
  final String? fotoUrl;
  final String? necessidadesEspeciais;
  final Timestamp? criadoEm;

  Aluno({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.localizacao,
    this.faculdade,
    required this.horarioEntrada,
    required this.horarioSaida,
    required this.statusPresenca,
    this.motoristaId,
    this.fotoUrl,
    this.necessidadesEspeciais,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'endereco': endereco,
      'localizacao': localizacao,
      'faculdade': faculdade,
      'horarioEntrada': horarioEntrada,
      'horarioSaida': horarioSaida,
      'statusPresenca': statusPresenca.name,
      'motoristaId': motoristaId,
      'fotoUrl': fotoUrl,
      'necessidadesEspeciais': necessidadesEspeciais,
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
    };
  }

  factory Aluno.fromMap(String id, Map<String, dynamic> data) {
    return Aluno(
      id: id,
      nome: data['nome'] ?? 'Nome não informado',
      endereco: data['endereco'] ?? '',
      // 🔹 🔹 🔹 A CORREÇÃO ESTÁ AQUI 🔹 🔹 🔹
      // Removido o 'const' de GeoPoint(0, 0)
      localizacao: (data['localizacao'] as GeoPoint?) ?? GeoPoint(0, 0),
      // 🔹 🔹 🔹 🔹 🔹 🔹 🔹 🔹 🔹 🔹 🔹 🔹 🔹 🔹 🔹
      faculdade: data['faculdade'],
      horarioEntrada: data['horarioEntrada'] ?? '',
      horarioSaida: data['horarioSaida'] ?? '',
      statusPresenca: StatusPresenca.values.firstWhere(
        (e) => e.name == data['statusPresenca'],
        orElse: () => StatusPresenca.desconhecido,
      ),
      motoristaId: data['motoristaId'],
      fotoUrl: data['fotoUrl'],
      necessidadesEspeciais: data['necessidadesEspeciais'],
      criadoEm: data['criadoEm'],
    );
  }
}

