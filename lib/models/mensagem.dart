import 'package:cloud_firestore/cloud_firestore.dart';

class Mensagem {
  final String id;
  final String senderId;
  final String texto;
  final Timestamp timestamp;

  Mensagem({
    required this.id,
    required this.senderId,
    required this.texto,
    required this.timestamp,
  });

  factory Mensagem.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception("Documento da mensagem não encontrado ou está vazio.");
    }

    final texto = data['texto'] ?? data['text'] ?? '';

    return Mensagem(
      id: snapshot.id,
      senderId: data['senderId'] ?? '',
      texto: texto,
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}
