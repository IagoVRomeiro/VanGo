import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusRota { planejada, emAndamento, concluida, cancelada }

class Rota {
  final String id;
  final String nome;
  final String vanId;
  final String motoristaId;
  final List<String> listaAlunosIds;
  final Timestamp horarioInicioPrevisto;
  final Timestamp horarioFimPrevisto;
  final Timestamp? horarioInicioReal;
  final Timestamp? horarioFimReal;
  final double distanciaTotal;
  final StatusRota status;
  final Timestamp? criadoEm;

  Rota({
    required this.id,
    required this.nome,
    required this.vanId,
    required this.motoristaId,
    required this.listaAlunosIds,
    required this.horarioInicioPrevisto,
    required this.horarioFimPrevisto,
    this.horarioInicioReal,
    this.horarioFimReal,
    required this.distanciaTotal,
    required this.status,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'vanId': vanId,
      'motoristaId': motoristaId,
      'listaAlunosIds': listaAlunosIds,
      'horarioInicioPrevisto': horarioInicioPrevisto,
      'horarioFimPrevisto': horarioFimPrevisto,
      'horarioInicioReal': horarioInicioReal,
      'horarioFimReal': horarioFimReal,
      'distanciaTotal': distanciaTotal,
      'status': status.name,
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
    };
  }

  factory Rota.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) throw Exception("Documento da rota não encontrado ou está vazio.");

    return Rota(
      id: snapshot.id,
      nome: data['nome'] ?? 'Rota sem nome',
      vanId: data['vanId'] ?? '',
      motoristaId: data['motoristaId'] ?? '',
      listaAlunosIds: List<String>.from(data['listaAlunosIds'] ?? []),
      horarioInicioPrevisto: data['horarioInicioPrevisto'] ?? Timestamp.now(),
      horarioFimPrevisto: data['horarioFimPrevisto'] ?? Timestamp.now(),
      horarioInicioReal: data['horarioInicioReal'],
      horarioFimReal: data['horarioFimReal'],
      distanciaTotal: (data['distanciaTotal'] as num?)?.toDouble() ?? 0.0,
      status: StatusRota.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => StatusRota.planejada,
      ),
      criadoEm: data['criadoEm'],
    );
  }
}
