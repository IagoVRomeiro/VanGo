import 'package:cloud_firestore/cloud_firestore.dart';

/// Define os papéis (roles) possíveis para um usuário no sistema.
enum UserRole {
  motorista,
  aluno,
  indefinido;

  /// Converte uma String do Firestore para o enum [UserRole].
  static UserRole fromString(String? role) {
    return UserRole.values.firstWhere(
      (e) => e.name == role,
      orElse: () => UserRole.indefinido,
    );
  }
}

/// Representa o documento de controle de acesso na coleção 'users' do Firestore.
/// Contém as informações básicas e o papel de cada usuário autenticado.
class Usuario {
  final String id; // UID do Firebase Auth
  final String nome;
  final String email;
  final String? telefone;
  final String? endereco;
  final UserRole role;
  final String? fotoUrl;
  final Timestamp? criadoEm;

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.role,
    this.telefone,
    this.endereco,
    this.fotoUrl,
    this.criadoEm,
  });

  /// Converte o objeto [Usuario] em um [Map] para salvar no Firestore.
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'email': email,
      'telefone': telefone,
      'endereco': endereco,
      'role': role.name,
      'fotoUrl': fotoUrl,
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
    };
  }

  /// Cria um objeto [Usuario] a partir de um documento do Firestore.
  factory Usuario.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception("Documento de usuário não encontrado ou está vazio.");
    }

    return Usuario(
      id: snapshot.id,
      nome: data['nome'] ?? 'Nome não informado',
      email: data['email'] ?? '',
      telefone: data['telefone'],
      endereco: data['endereco'],
      role: UserRole.fromString(data['role']),
      fotoUrl: data['fotoUrl'],
      criadoEm: data['criadoEm'],
    );
  }
}