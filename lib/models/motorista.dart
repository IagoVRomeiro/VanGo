import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusMotorista {
  disponivel,
  emRota,
  indisponivel;

  static StatusMotorista fromString(String? status) {
    return StatusMotorista.values.firstWhere(
      (e) => e.name == status,
      orElse: () => StatusMotorista.indisponivel,
    );
  }
}

class Motorista {
  final String id;
  final String nome;
  final String cpf;
  final String cnh;
  final String telefone;
  final String email;
  final String endereco;
  final double avaliacao;
  final StatusMotorista status;
  final String? fotoUrl;
  final String? veiculo;
  final Timestamp? criadoEm;
  // 🔹 ADICIONADO: Lista de IDs de alunos vinculados
  final List<String>? alunosIds;

  Motorista({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.cnh,
    required this.telefone,
    required this.email,
    required this.endereco,
    required this.avaliacao,
    required this.status,
    this.fotoUrl,
    this.veiculo,
    this.criadoEm,
    // 🔹 ADICIONADO
    this.alunosIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'cpf': cpf,
      'cnh': cnh,
      'telefone': telefone,
      'email': email,
      'endereco': endereco,
      'avaliacao': avaliacao,
      'status': status.name,
      'fotoUrl': fotoUrl,
      'veiculo': veiculo,
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
      // 🔹 ADICIONADO
      'alunosIds': alunosIds ?? [],
    };
  }


  factory Motorista.fromMap(String id, Map<String, dynamic> data) {
    return Motorista(
      id: id,
      nome: data['nome'] ?? 'Nome não informado',
      cpf: data['cpf'] ?? '',
      cnh: data['cnh'] ?? '',
      telefone: data['telefone'] ?? '',
      email: data['email'] ?? '',
      endereco: data['endereco'] ?? '',
      avaliacao: (data['avaliacao'] as num?)?.toDouble() ?? 0.0,
      status: StatusMotorista.fromString(data['status']),
      fotoUrl: data['fotoUrl'],
      veiculo: data['veiculo'],
      criadoEm: data['criadoEm'],
      // 🔹 ADICIONADO: Converte o campo do Firestore para uma lista de Strings
      alunosIds: List<String>.from(data['alunosIds'] ?? []),
    );
  }
}

