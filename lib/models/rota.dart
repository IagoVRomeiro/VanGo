// lib/models/rota.dart

// É preciso importar as classes com as quais a Rota se relaciona
import 'aluno.dart';
import 'motorista.dart';
import 'van.dart';

class Rota {
  String id;
  String nome; // Ex: "Manhã - Escola A"
  
  // --- Relações com outras classes (objetos completos) ---
  Van van;
  Motorista motorista;
  List<Aluno> listaAlunos;

  // --- Atributos de Horário ---
  DateTime horarioInicioPrevisto;
  DateTime horarioFimPrevisto;
  DateTime? horarioInicioReal; // Pode ser nulo
  DateTime? horarioFimReal;   // Pode ser nulo
  
  // --- Outros Atributos ---
  double distanciaTotal; // Em km
  String status; // "planejada", "em andamento", "concluída", "cancelada"

  // Construtor principal
  Rota({
    required this.id,
    required this.nome,
    required this.van,
    required this.motorista,
    required this.listaAlunos,
    required this.horarioInicioPrevisto,
    required this.horarioFimPrevisto,
    this.horarioInicioReal,
    this.horarioFimReal,
    required this.distanciaTotal,
    required this.status,
  });

  /// Converte o objeto [Rota] em um [Map<String, dynamic>] para o Firebase.
  /// Note como os objetos aninhados e a lista são convertidos.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      // Converte os objetos aninhados chamando seus próprios métodos toMap()
      'van': van.toMap(),
      'motorista': motorista.toMap(),
      // Converte cada aluno na lista para um Map
      'listaAlunos': listaAlunos.map((aluno) => aluno.toMap()).toList(),
      // Converte DateTime para um formato que o Firestore entende bem (ISO 8601 String)
      'horarioInicioPrevisto': horarioInicioPrevisto.toIso8601String(),
      'horarioFimPrevisto': horarioFimPrevisto.toIso8601String(),
      'horarioInicioReal': horarioInicioReal?.toIso8601String(),
      'horarioFimReal': horarioFimReal?.toIso8601String(),
      'distanciaTotal': distanciaTotal,
      'status': status,
    };
  }

  /// Cria um objeto [Rota] a partir de um [Map<String, dynamic>] vindo do Firebase.
  factory Rota.fromMap(Map<String, dynamic> map) {
    return Rota(
      id: map['id'] ?? '',
      nome: map['nome'] ?? 'Rota sem nome',
      // Cria os objetos aninhados chamando seus próprios métodos fromMap()
      van: Van.fromMap(map['van'] ?? {}),
      motorista: Motorista.fromMap(map['motorista'] ?? {}),
      // Mapeia a lista de Maps de alunos para uma lista de objetos Aluno
      listaAlunos: List<Aluno>.from(
        (map['listaAlunos'] as List<dynamic>? ?? []).map(
          (alunoMap) => Aluno.fromMap(alunoMap),
        ),
      ),
      // Converte a String ISO 8601 de volta para DateTime
      horarioInicioPrevisto: DateTime.parse(map['horarioInicioPrevisto'] ?? DateTime.now().toIso8601String()),
      horarioFimPrevisto: DateTime.parse(map['horarioFimPrevisto'] ?? DateTime.now().toIso8601String()),
      horarioInicioReal: map['horarioInicioReal'] != null ? DateTime.parse(map['horarioInicioReal']) : null,
      horarioFimReal: map['horarioFimReal'] != null ? DateTime.parse(map['horarioFimReal']) : null,
      distanciaTotal: (map['distanciaTotal'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'planejada',
    );
  }
}