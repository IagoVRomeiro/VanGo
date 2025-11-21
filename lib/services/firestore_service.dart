import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirebaseFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addMotorista({
    required String nome,
    required String cnpj,
    required String placaVan,
    required String universidade,
  }) async {
    try {
      await _db.collection('motoristas').add({
        'nome': nome,
        'cnpj': cnpj,
        'placaVan': placaVan,
        'universidade': universidade,
        'dataCadastro': FieldValue.serverTimestamp(),
        'status': 'ativo',
      });
  
      debugPrint('Motorista $nome adicionado com sucesso!');
    } catch (e) {
 
      debugPrint('Erro ao adicionar motorista: $e');
    }
  }

  // --- Obter a Lista de Motoristas (em tempo real) ---
  Stream<QuerySnapshot> getMotoristasStream() {
    return _db.collection('motoristas')
          .orderBy('nome')
          .snapshots();
  }

  // --- Obter um Motorista por ID (exemplo) ---
  Future<DocumentSnapshot?> getMotoristaById(String motoristaId) async {
    try {
      return await _db.collection('motoristas').doc(motoristaId).get();
    } catch (e) {
      debugPrint('Erro ao buscar motorista por ID: $e');
      return null;
    }
  }

  // --- Atualizar um Motorista (exemplo) ---
  Future<void> updateMotorista(String motoristaId, Map<String, dynamic> data) async {
    try {
      await _db.collection('motoristas').doc(motoristaId).update(data);
      debugPrint('Motorista $motoristaId atualizado com sucesso!');
    } catch (e) {
      debugPrint('Erro ao atualizar motorista: $e');
    }
  }

  // --- Adicionar uma Nova Rota ---
  Future<void> addRota({
    required String nomeRota,
    required String universidade,
    required String pontoPartida,
    required String pontoChegada,

  }) async {
    try {
      await _db.collection('rotas').add({
        'nomeRota': nomeRota,
        'universidade': universidade,
        'pontoPartida': pontoPartida,
        'pontoChegada': pontoChegada,
        'dataCriacao': FieldValue.serverTimestamp(),
        // 'motoristaId': idDoMotoristaLogado,
      });
      debugPrint('Rota "$nomeRota" adicionada com sucesso!');
    } catch (e) {
      debugPrint('Erro ao adicionar rota: $e');
    }
  }
}

