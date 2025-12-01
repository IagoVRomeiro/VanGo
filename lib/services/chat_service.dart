import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vango/models/chat.dart';

/// Serviço utilitário para padronizar a criação/resgate de chats
/// entre aluno e motorista, evitando duplicidades e mantendo
/// campos auxiliares (pairKey, status, timestamps) sincronizados.
class ChatService {
  ChatService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String buildPairKey(String userA, String userB) {
    final ids = [userA, userB]..sort();
    return ids.join('_');
  }

  /// Garante a existência de um chat entre aluno/motorista.
  /// Quando [activate] é true o chat fica disponível imediatamente.
  static Future<String> ensureChat({
    required String alunoId,
    required String motoristaId,
    bool activate = false,
    String? initialText,
  }) async {
    final pairKey = buildPairKey(alunoId, motoristaId);
    final chatsRef = _firestore.collection('chats');

    DocumentSnapshot<Map<String, dynamic>>? existingDoc;

    final pairQuery =
        await chatsRef.where('pairKey', isEqualTo: pairKey).limit(1).get();
    if (pairQuery.docs.isNotEmpty) {
      existingDoc = pairQuery.docs.first;
    } else {
      final legacyQuery =
          await chatsRef.where('participants', arrayContains: alunoId).get();
      for (final doc in legacyQuery.docs) {
        final participants =
            List<String>.from(doc.data()['participants'] ?? <String>[]);
        if (participants.contains(motoristaId)) {
          existingDoc = doc;
          break;
        }
      }
    }

    if (existingDoc != null) {
      final existingStatus = existingDoc.data()?['status'] as String?;
      final dataToMerge = <String, dynamic>{
        'pairKey': pairKey,
        'alunoId': alunoId,
        'motoristaId': motoristaId,
        'participants': FieldValue.arrayUnion([alunoId, motoristaId]),
      };

      if (activate) {
        dataToMerge.addAll({
          'status': ChatStatus.active.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (existingStatus == null || existingStatus.isEmpty) {
        dataToMerge['status'] = ChatStatus.inquiry.name;
      }

      await existingDoc.reference.set(dataToMerge, SetOptions(merge: true));
      return existingDoc.id;
    }

    final serverTimestamp = FieldValue.serverTimestamp();
    final docRef = chatsRef.doc();
    final status = activate ? ChatStatus.active.name : ChatStatus.inquiry.name;
    final lastMessage = {
      'text': initialText ??
          (activate ? 'Conversa iniciada.' : 'Nova solicitação de contato'),
      'senderId': activate ? motoristaId : alunoId,
      'timestamp': serverTimestamp,
    };

    await docRef.set({
      'participants': [alunoId, motoristaId],
      'alunoId': alunoId,
      'motoristaId': motoristaId,
      'pairKey': pairKey,
      'status': status,
      'createdAt': serverTimestamp,
      'updatedAt': serverTimestamp,
      'lastMessage': lastMessage,
    });

    return docRef.id;
  }
}
