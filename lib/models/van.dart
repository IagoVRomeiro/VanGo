// lib/models/van.dart

class Van {
  // --- Atributos de Identificação (essencial para o aluno) ---
  String placa; // Usado como ID único do veículo
  String modelo;
  String marca;
  String cor;
  String? fotoUrl;                // Opcional, mas muito útil para o aluno identificar a van

  // --- Atributos Operacionais (essencial para a rota) ---
  int ano;
  int capacidade; // Número máximo de alunos (regra de negócio crucial)
  bool documentacaoValida; // Importante para segurança e legalidade
  String status; // "disponível", "em manutenção", "em rota"
  
  // --- Relação com o motorista ---
  String motoristaId; 

  // Construtor principal da classe (agora mais simples)
  Van({
    required this.placa,
    required this.modelo,
    required this.marca,
    required this.ano,
    required this.capacidade,
    required this.cor,
    required this.documentacaoValida,
    required this.status,
    required this.motoristaId,
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
      'documentacaoValida': documentacaoValida,
      'status': status,
      'motoristaId': motoristaId,
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
      documentacaoValida: map['documentacaoValida'] ?? false,
      status: map['status'] ?? 'indisponível',
      motoristaId: map['motoristaId'] ?? '',
      fotoUrl: map['fotoUrl'],
    );
  }
}