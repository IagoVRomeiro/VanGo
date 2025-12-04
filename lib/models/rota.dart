import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusRota {
  planejada,
  emAndamento,
  concluida,
  cancelada;

  static StatusRota fromString(String? status) {
    return StatusRota.values.firstWhere(
      (e) => e.name == status,
      orElse: () => StatusRota.planejada,
    );
  }
}

class Rota {
  final String id;
  final String nome;
  final String vanId;
  final String motoristaId;
  final GeoPoint localDestino;
  final String localDestinoNome;
  final List<String> listaAlunosIds;
  final Map<String, bool> diasSemana;
  final String horarioInicioPrevisto;
  final String horarioFimPrevisto;
  final Timestamp? horaInicio; // Novo campo
  final StatusRota status;
  final Timestamp? criadoEm;

  Rota({
    required this.id,
    required this.nome,
    required this.vanId,
    required this.motoristaId,
    required this.localDestino,
    required this.localDestinoNome,
    required this.listaAlunosIds,
    required this.diasSemana,
    required this.horarioInicioPrevisto,
    required this.horarioFimPrevisto,
    this.horaInicio, // Novo campo
    required this.status,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'vanId': vanId,
      'motoristaId': motoristaId,
      'localDestino': localDestino,
      'localDestinoNome': localDestinoNome,
      'listaAlunosIds': listaAlunosIds,
      'diasSemana': diasSemana,
      'horarioInicioPrevisto': horarioInicioPrevisto,
      'horarioFimPrevisto': horarioFimPrevisto,
      'horaInicio': horaInicio, // Novo campo
      'status': status.name,
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
    };
  }
  
  Map<String, dynamic> toUpdateMap() {
    return {
      'nome': nome,
      'vanId': vanId,
      'motoristaId': motoristaId,
      'localDestino': localDestino,
      'localDestinoNome': localDestinoNome,
      'listaAlunosIds': listaAlunosIds,
      'diasSemana': diasSemana,
      'horarioInicioPrevisto': horarioInicioPrevisto,
      'horarioFimPrevisto': horarioFimPrevisto,
      'horaInicio': horaInicio, // Novo campo
      'status': status.name,
    };
  }


  factory Rota.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) throw Exception("Documento da rota não encontrado.");

    GeoPoint localDestinoPoint;
    String localDestinoNomeString = data['localDestinoNome'] ?? '';

    if (data['localDestino'] is String) {
      localDestinoPoint = const GeoPoint(0, 0); // Padrão, já que não podemos converter
      localDestinoNomeString = data['localDestino'];
    } else if (data['localDestino'] is GeoPoint) {
      localDestinoPoint = data['localDestino'];
    } else {
      localDestinoPoint = const GeoPoint(0, 0);
    }


    return Rota(
      id: snapshot.id,
      nome: data['nome'] ?? 'Rota sem nome',
      vanId: data['vanId'] ?? '',
      motoristaId: data['motoristaId'] ?? '',
      localDestino: localDestinoPoint,
      localDestinoNome: localDestinoNomeString,
      listaAlunosIds: List<String>.from(data['listaAlunosIds'] ?? []),
      diasSemana: (data['diasSemana'] as Map?)?.cast<String, bool>() ?? {},
      horarioInicioPrevisto: data['horarioInicioPrevisto'] ?? '00:00',
      horarioFimPrevisto: data['horarioFimPrevisto'] ?? '00:00',
      horaInicio: data['horaInicio'] as Timestamp?, // Novo campo
      status: StatusRota.fromString(data['status']),
      criadoEm: data['criadoEm'],
    );
  }
}
