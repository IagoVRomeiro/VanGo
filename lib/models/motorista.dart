// lib/models/motorista.dart

class Motorista {
  String id;
  String nome;
  String cpf;
  String cnh; // Número da carteira de habilitação
  String telefone;
  String email;
  String endereco;
  int experiencia; // Anos de experiência
  double avaliacao; // Nota média
  String status; // Ex: "disponível", "em rota", "indisponível"

  // Construtor principal da classe
  Motorista({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.cnh,
    required this.telefone,
    required this.email,
    required this.endereco,
    required this.experiencia,
    required this.avaliacao,
    required this.status,
  });

  /// Converte o objeto [Motorista] em um [Map<String, dynamic>].
  /// Útil para enviar dados para o Firebase (Firestore).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'cpf': cpf,
      'cnh': cnh,
      'telefone': telefone,
      'email': email,
      'endereco': endereco,
      'experiencia': experiencia,
      'avaliacao': avaliacao,
      'status': status,
    };
  }

  /// Cria um objeto [Motorista] a partir de um [Map<String, dynamic>].
  /// Útil para receber dados do Firebase (Firestore).
  factory Motorista.fromMap(Map<String, dynamic> map) {
    return Motorista(
      id: map['id'] ?? '', // O '??' protege contra valores nulos
      nome: map['nome'] ?? 'Nome não informado',
      cpf: map['cpf'] ?? '',
      cnh: map['cnh'] ?? '',
      telefone: map['telefone'] ?? '',
      email: map['email'] ?? '',
      endereco: map['endereco'] ?? '',
      experiencia: map['experiencia'] ?? 0,
      avaliacao: (map['avaliacao'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'indisponível',
    );
  }
}