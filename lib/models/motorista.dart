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
  final String nome;
  final String cpf;
  final String cnh;
  final String telefone;
  final String email;
  final String endereco;
  final double avaliacao;
  final StatusMotorista status;
  final Timestamp? criadoEm;
  final List<String>? alunosIds;
  final String? vanId; 

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
    this.criadoEm,
    this.alunosIds,
    this.vanId,
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
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
      'alunosIds': alunosIds ?? [],
      'vanId': vanId, 
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
      criadoEm: data['criadoEm'],
      alunosIds: List<String>.from(data['alunosIds'] ?? []),
      vanId: data['vanId'], 
    );
  }
}