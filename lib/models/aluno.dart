// lib/models/aluno.dart (VERSÃO COMPLETA E CORRIGIDA)

import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusPresenca { presente, ausente, embarcou, desembarcou, desconhecido }

class Aluno {
  final String id;
  final String nome;
  final int idade;
  final String serie;
  final String endereco;
  final GeoPoint localizacao;
  final String faculdade;
  final String horarioEntrada;
  final String horarioSaida;
  final StatusPresenca statusPresenca;
  final String motoristaId; // ✅ CAMPO ADICIONADO
  final String? fotoUrl;
  final String? necessidadesEspeciais;
  final Timestamp? criadoEm;

  Aluno({
    required this.id,
    required this.nome,
    required this.idade,
    required this.serie,
    required this.endereco,
    required this.localizacao,
    required this.faculdade,
    required this.horarioEntrada,
    required this.horarioSaida,
    required this.statusPresenca,
    required this.motoristaId, // ✅ CAMPO ADICIONADO AO CONSTRUTOR
    this.fotoUrl,
    this.necessidadesEspeciais,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'idade': idade,
      'serie': serie,
      'endereco': endereco,
      'localizacao': localizacao,
      'faculdade': faculdade,
      'horarioEntrada': horarioEntrada,
      'horarioSaida': horarioSaida,
      'statusPresenca': statusPresenca.name,
      'motoristaId': motoristaId, // ✅ CAMPO ADICIONADO AO MAPA
      'fotoUrl': fotoUrl,
      'necessidadesEspeciais': necessidadesEspeciais,
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
    };
  }

  // ✅ MÉTODO RENOMEADO E AJUSTADO
  factory Aluno.fromMap(String id, Map<String, dynamic> data) {
    return Aluno(
      id: id,
      nome: data['nome'] ?? 'Nome não informado',
      idade: data['idade'] ?? 0,
      serie: data['serie'] ?? '',
      endereco: data['endereco'] ?? '',
      localizacao: data['localizacao'] ?? const GeoPoint(0, 0),
      faculdade: data['faculdade'] ?? '',
      horarioEntrada: data['horarioEntrada'] ?? '',
      horarioSaida: data['horarioSaida'] ?? '',
      statusPresenca: StatusPresenca.values.firstWhere(
        (e) => e.name == data['statusPresenca'],
        orElse: () => StatusPresenca.desconhecido,
      ),
      motoristaId: data['motoristaId'] ?? '', // ✅ CAMPO ADICIONADO
      fotoUrl: data['fotoUrl'],
      necessidadesEspeciais: data['necessidadesEspeciais'],
      criadoEm: data['criadoEm'],
    );
  }
}