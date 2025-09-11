// services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Adicionar um Novo Motorista ---
  Future<void> addMotorista({
    required String nome,
    required String cnpj,
    required String placaVan,
    required String universidade,
  }) async {
    try {
      // Adiciona um novo documento à coleção 'motoristas'.
      // O '.add()' cria um ID de documento automaticamente.
      await _db.collection('motoristas').add({
        'nome': nome,
        'cnpj': cnpj,
        'placaVan': placaVan,
        'universidade': universidade,
        'dataCadastro': FieldValue.serverTimestamp(), // Adiciona o timestamp do servidor
        'status': 'ativo', // Exemplo de campo de status
      });
      print('Motorista $nome adicionado com sucesso!');
    } catch (e) {
      print('Erro ao adicionar motorista: $e');
      // Você pode lançar uma exceção ou retornar um valor para tratamento de erro na UI.
    }
  }

  // --- Obter a Lista de Motoristas (em tempo real) ---
  // Retorna um Stream de QuerySnapshot, que será atualizado sempre que houver mudanças.
  Stream<QuerySnapshot> getMotoristasStream() {
    return _db.collection('motoristas')
              .orderBy('nome') // Opcional: ordenar por nome
              .snapshots();
  }

  // --- Obter um Motorista por ID (exemplo) ---
  Future<DocumentSnapshot?> getMotoristaById(String motoristaId) async {
    try {
      return await _db.collection('motoristas').doc(motoristaId).get();
    } catch (e) {
      print('Erro ao buscar motorista por ID: $e');
      return null;
    }
  }

  // --- Atualizar um Motorista (exemplo) ---
  Future<void> updateMotorista(String motoristaId, Map<String, dynamic> data) async {
    try {
      await _db.collection('motoristas').doc(motoristaId).update(data);
      print('Motorista $motoristaId atualizado com sucesso!');
    } catch (e) {
      print('Erro ao atualizar motorista: $e');
    }
  }

  // --- Deletar um Motorista (exemplo) ---
  Future<void> deleteMotorista(String motoristaId) async {
    try {
      await _db.collection('motoristas').doc(motoristaId).delete();
      print('Motorista $motoristaId deletado com sucesso!');
    } catch (e) {
      print('Erro ao deletar motorista: $e');
    }
  }
}
