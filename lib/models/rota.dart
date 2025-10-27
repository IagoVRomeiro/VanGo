// lib/models/rota.dart
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
  final String localDestino; // ⬅️ CAMPO NOVO
  final List<String> listaAlunosIds;
  final Map<String, bool> diasSemana; // ⬅️ CAMPO NOVO
  final String horarioInicioPrevisto; // ⬅️ TIPO MUDADO
  final String horarioFimPrevisto;  // ⬅️ TIPO MUDADO
  final StatusRota status;
  final Timestamp? criadoEm;

  Rota({
    required this.id,
    required this.nome,
    required this.vanId,
    required this.motoristaId,
    required this.localDestino, // ⬅️ NOVO
    required this.listaAlunosIds,
    required this.diasSemana, // ⬅️ NOVO
    required this.horarioInicioPrevisto, // ⬅️ MUDADO
    required this.horarioFimPrevisto, // ⬅️ MUDADO
    required this.status,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'vanId': vanId,
      'motoristaId': motoristaId,
      'localDestino': localDestino,
      'listaAlunosIds': listaAlunosIds,
      'diasSemana': diasSemana,
      'horarioInicioPrevisto': horarioInicioPrevisto,
      'horarioFimPrevisto': horarioFimPrevisto,
      'status': status.name,
      // Se 'criadoEm' for nulo, NÃO o adicione (para updates)
      // Se não for nulo (modo de edição), adicione
      // Se for nulo E não for modo de edição (novo), use serverTimestamp
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
    };
  }
  
  // Um toMap seguro para Updates (que não mexe no 'criadoEm')
  Map<String, dynamic> toUpdateMap() {
    return {
      'nome': nome,
      'vanId': vanId,
      'motoristaId': motoristaId,
      'localDestino': localDestino,
      'listaAlunosIds': listaAlunosIds,
      'diasSemana': diasSemana,
      'horarioInicioPrevisto': horarioInicioPrevisto,
      'horarioFimPrevisto': horarioFimPrevisto,
      'status': status.name,
      // NÃO inclui 'criadoEm' para não sobrescrevê-lo
    };
  }


  factory Rota.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) throw Exception("Documento da rota não encontrado.");

    return Rota(
      id: snapshot.id,
      nome: data['nome'] ?? 'Rota sem nome',
      vanId: data['vanId'] ?? '',
      motoristaId: data['motoristaId'] ?? '',
      localDestino: data['localDestino'] ?? '', // ⬅️ NOVO
      listaAlunosIds: List<String>.from(data['listaAlunosIds'] ?? []),
      diasSemana: (data['diasSemana'] as Map?)?.cast<String, bool>() ?? {}, // ⬅️ NOVO
      horarioInicioPrevisto: data['horarioInicioPrevisto'] ?? '00:00', // ⬅️ MUDADO
      horarioFimPrevisto: data['horarioFimPrevisto'] ?? '00:00', // ⬅️ MUDADO
      status: StatusRota.fromString(data['status']),
      criadoEm: data['criadoEm'],
    );
  }
}