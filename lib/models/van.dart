// lib/models/van.dart

class Van {
  String placa; // Usado como ID único do veículo
  String modelo;
  String marca;
  int ano;
  int capacidade; // Número máximo de alunos
  String cor;
  double quilometragem;
  bool documentacaoValida;
  String status; // "disponível", "em manutenção", "em rota"
  
  // Relação com o motorista - o ideal é salvar o ID
  String motoristaId; 

  // Atributos adicionais úteis
  DateTime? dataUltimaManutencao; // Opcional
  String? fotoUrl;                // Opcional

  // Construtor principal da classe
  Van({
    required this.placa,
    required this.modelo,
    required this.marca,
    required this.ano,
    required this.capacidade,
    required this.cor,
    required this.quilometragem,
    required this.documentacaoValida,
    required this.status,
    required this.motoristaId,
    this.dataUltimaManutencao,
    this.fotoUrl,
  });

  /// Converte o objeto [Van] em um [Map<String, dynamic>] para o Firebase.
  Map<String, dynamic> toMap() {
    return {
      'placa': placa,
      'modelo': modelo,
      'marca': marca,
      'ano': ano,
      'capacidade': capacidade,
      'cor': cor,
      'quilometragem': quilometragem,
      'documentacaoValida': documentacaoValida,
      'status': status,
      'motoristaId': motoristaId,
      'dataUltimaManutencao': dataUltimaManutencao?.toIso8601String(),
      'fotoUrl': fotoUrl,
    };
  }

  /// Cria um objeto [Van] a partir de um [Map<String, dynamic>] vindo do Firebase.
  factory Van.fromMap(Map<String, dynamic> map) {
    return Van(
      placa: map['placa'] ?? '',
      modelo: map['modelo'] ?? '',
      marca: map['marca'] ?? '',
      ano: map['ano'] ?? DateTime.now().year,
      capacidade: map['capacidade'] ?? 0,
      cor: map['cor'] ?? '',
      quilometragem: (map['quilometragem'] as num?)?.toDouble() ?? 0.0,
      documentacaoValida: map['documentacaoValida'] ?? false,
      status: map['status'] ?? 'indisponível',
      motoristaId: map['motoristaId'] ?? '',
      dataUltimaManutencao: map['dataUltimaManutencao'] != null 
          ? DateTime.parse(map['dataUltimaManutencao']) 
          : null,
      fotoUrl: map['fotoUrl'],
    );
  }
}