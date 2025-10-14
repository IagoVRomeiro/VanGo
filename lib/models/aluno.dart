// lib/models/aluno.dart

class Aluno {
  String id;
  String nome;
  int idade;
  String serie;
  String endereco;
  double latitude;
  double longitude;
  String escola;
  String horarioEntrada;
  String horarioSaida;
  String contatoResponsavel;
  String statusPresenca;
  String idResponsavel;
  String? fotoUrl;
  String? necessidadesEspeciais;
  String motoristaId; // ✅ CAMPO ADICIONADO AQUI

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
    this.fotoUrl,
    this.necessidadesEspeciais,
    required this.motoristaId, // ✅ ADICIONADO AO CONSTRUTOR
  });

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
      'motoristaId': motoristaId, // ✅ ADICIONADO AO MAPA
    };
  }

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
      fotoUrl: map['fotoUrl'],
      necessidadesEspeciais: map['necessidadesEspeciais'],
      motoristaId: map['motoristaId'] ?? '', // ✅ ADICIONADO AO FACTORY
    );
  }
}