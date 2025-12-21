// vango 1.0
import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusPresenca { presente, ausente, embarcou }

class Aluno {
  final String id;
  final GeoPoint localizacao;
  final StatusPresenca statusPresenca;
  final List<String> motoristasIds;
  final Timestamp? criadoEm;

  Aluno({
    required this.id,
    required this.localizacao,
    required this.statusPresenca,
    this.motoristasIds = const [],
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'localizacao': localizacao,
      'statusPresenca': statusPresenca.name,
      'motoristasIds': motoristasIds,
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
    };
  }

  factory Aluno.fromMap(String id, Map<String, dynamic> data) {
    return Aluno(
      id: id,
      localizacao: (data['localizacao'] as GeoPoint?) ?? const GeoPoint(0, 0),
      statusPresenca: StatusPresenca.values.firstWhere(
        (e) => e.name == data['statusPresenca'],
        orElse: () => StatusPresenca.ausente,
      ),
      motoristasIds: Aluno.motoristasIdsFromMap(data),
      criadoEm: data['criadoEm'],
    );
  }

  static List<String> motoristasIdsFromMap(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final motoristasRaw = data['motoristasIds'];
    if (motoristasRaw is Iterable) {
      return motoristasRaw.whereType<String>().toSet().toList();
    }
    final motoristaId = data['motoristaId'];
    if (motoristaId is String && motoristaId.isNotEmpty) {
      return [motoristaId];
    }
    return const [];
  }
}

