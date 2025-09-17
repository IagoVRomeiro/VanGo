// lib/models/aluno.dart

class Aluno {
  String id;
  String nome;
  int idade;
  String serie; // Ex: "5º Ano B"
  String endereco;
  double latitude;
  double longitude;
  String escola;
  String horarioEntrada; // Ex: "07:30"
  String horarioSaida;   // Ex: "12:30"
  String contatoResponsavel; // Telefone do responsável
  String statusPresenca; // "confirmado", "ausente", "embarcado", "desembarcado"
  
  // Atributos adicionais sugeridos que são muito úteis
  String idResponsavel; // ID do documento do responsável no Firebase
  String? fotoUrl; // URL da foto do aluno (opcional, por isso o '?')
  String? necessidadesEspeciais; // Descrição de necessidades especiais (opcional)

  // Construtor principal da classe
  Aluno({
    required this.id,
    required this.nome,
    required this.idade,
    required this.serie,
    required this.endereco,
    required this.latitude,
    required this.longitude,
    required this.escola,
    required this.horarioEntrada,
    required this.horarioSaida,
    required this.contatoResponsavel,
    required this.statusPresenca,
    required this.idResponsavel,
    this.fotoUrl, // Atributos opcionais não precisam de 'required'
    this.necessidadesEspeciais,
  });

  /// Converte o objeto [Aluno] em um [Map<String, dynamic>].
  /// Útil para enviar dados para o Firebase (Firestore).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'idade': idade,
      'serie': serie,
      'endereco': endereco,
      'latitude': latitude,
      'longitude': longitude,
      'escola': escola,
      'horarioEntrada': horarioEntrada,
      'horarioSaida': horarioSaida,
      'contatoResponsavel': contatoResponsavel,
      'statusPresenca': statusPresenca,
      'idResponsavel': idResponsavel,
      'fotoUrl': fotoUrl,
      'necessidadesEspeciais': necessidadesEspeciais,
    };
  }

  /// Cria um objeto [Aluno] a partir de um [Map<String, dynamic>].
  /// Útil para receber dados do Firebase (Firestore).
  factory Aluno.fromMap(Map<String, dynamic> map) {
    return Aluno(
      id: map['id'] ?? '',
      nome: map['nome'] ?? 'Nome não informado',
      idade: map['idade'] ?? 0,
      serie: map['serie'] ?? '',
      endereco: map['endereco'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      escola: map['escola'] ?? '',
      horarioEntrada: map['horarioEntrada'] ?? '',
      horarioSaida: map['horarioSaida'] ?? '',
      contatoResponsavel: map['contatoResponsavel'] ?? '',
      statusPresenca: map['statusPresenca'] ?? 'desconhecido',
      idResponsavel: map['idResponsavel'] ?? '',
      fotoUrl: map['fotoUrl'], // Se for nulo no Firebase, continuará nulo aqui
      necessidadesEspeciais: map['necessidadesEspeciais'],
    );
  }
}