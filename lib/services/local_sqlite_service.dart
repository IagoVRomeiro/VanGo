import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Serviço simples usando SQLite para cache local.
/// Mantém pares chave/valor em JSON para reutilizar junto ao Hive.
class LocalSqliteService {
  LocalSqliteService._();
  static final LocalSqliteService instance = LocalSqliteService._();

  static const _nomeBanco = 'vango_cache.db';
  static const _tabelaCache = 'cache';

  Database? _bancoDados;
  final Map<String, String> _cacheMemoria = {};

  @visibleForTesting
  DatabaseFactory? fabricaBancoTeste;

  @visibleForTesting
  Database? get bancoDepuracao => _bancoDados;

  Future<void> init() async {
    if (_bancoDados != null) return;

    final fabrica = fabricaBancoTeste ?? databaseFactory;
    final caminhoBanco = await fabrica.getDatabasesPath();
    final caminhoCompleto = p.join(caminhoBanco, _nomeBanco);
    _bancoDados = await fabrica.openDatabase(
      caminhoCompleto,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE $_tabelaCache(
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            );
          ''');
        },
      ),
    );
    await _hidratarCacheMemoria();
  }

  Future<void> salvarUsuario(String usuarioId, Map<String, dynamic> dados) =>
      _salvarBruto('user_$usuarioId', jsonEncode(dados));

  Future<void> salvarRotas(List<Map<String, dynamic>> rotas) =>
      _salvarBruto('rotas', jsonEncode(rotas));

  Future<void> salvarRotaAtual(Map<String, dynamic> rota) =>
      _salvarBruto('rota_atual', jsonEncode(rota));

  Future<void> salvarAlunos(List<Map<String, dynamic>> alunos) =>
      _salvarBruto('alunos', jsonEncode(alunos));

  Future<Map<String, dynamic>?> buscarUsuario(String usuarioId) =>
      _buscarJson('user_$usuarioId');

  Future<List<Map<String, dynamic>>> buscarRotas() async =>
      _buscarListaJson('rotas');

  Future<Map<String, dynamic>?> buscarRotaAtual() =>
      _buscarJson('rota_atual');

  Future<List<Map<String, dynamic>>> buscarAlunos() async =>
      _buscarListaJson('alunos');

  Map<String, dynamic>? buscarUsuarioSync(String usuarioId) =>
      _buscarJsonSync('user_$usuarioId');

  List<Map<String, dynamic>> buscarRotasSync() =>
      _buscarListaJsonSync('rotas');

  Map<String, dynamic>? buscarRotaAtualSync() =>
      _buscarJsonSync('rota_atual');

  List<Map<String, dynamic>> buscarAlunosSync() =>
      _buscarListaJsonSync('alunos');

  Future<void> _salvarBruto(String chave, String valor) async {
    if (_bancoDados == null) return;
    try {
      await _bancoDados!.insert(
        _tabelaCache,
        {'key': chave, 'value': valor},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _cacheMemoria[chave] = valor;
    } catch (e) {
      debugPrint('LocalSqliteService erro ao salvar $chave: $e');
    }
  }

  @visibleForTesting
  Future<void> salvarBrutoParaTeste(String chave, String valor) =>
      _salvarBruto(chave, valor);

  Future<Map<String, dynamic>?> _buscarJson(String chave) async {
    final bruto = await _buscarBruto(chave);
    if (bruto == null) return null;
    try {
      return jsonDecode(bruto) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('LocalSqliteService erro ao ler json $chave: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _buscarListaJson(String chave) async {
    final bruto = await _buscarBruto(chave);
    if (bruto == null) return [];
    try {
      final decodificado = jsonDecode(bruto) as List<dynamic>;
      return decodificado.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('LocalSqliteService erro ao ler lista $chave: $e');
      return [];
    }
  }

  @visibleForTesting
  Future<String?> buscarBrutoParaTeste(String chave) => _buscarBruto(chave);

  Map<String, dynamic>? _buscarJsonSync(String chave) {
    final bruto = _cacheMemoria[chave];
    if (bruto == null) return null;
    try {
      return jsonDecode(bruto) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('LocalSqliteService erro ao ler json sync $chave: $e');
      return null;
    }
  }

  List<Map<String, dynamic>> _buscarListaJsonSync(String chave) {
    final bruto = _cacheMemoria[chave];
    if (bruto == null) return [];
    try {
      final decodificado = jsonDecode(bruto) as List<dynamic>;
      return decodificado.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('LocalSqliteService erro ao ler lista sync $chave: $e');
      return [];
    }
  }

  Future<String?> _buscarBruto(String chave) async {
    if (_bancoDados == null) return null;
    try {
      final resultado = await _bancoDados!.query(
        _tabelaCache,
        where: 'key = ?',
        whereArgs: [chave],
        limit: 1,
      );
      if (resultado.isEmpty) return null;
      return resultado.first['value'] as String;
    } catch (e) {
      debugPrint('LocalSqliteService erro ao buscar $chave: $e');
      return null;
    }
  }

  Future<void> _hidratarCacheMemoria() async {
    if (_bancoDados == null) return;
    try {
      final linhas = await _bancoDados!.query(_tabelaCache);
      for (final linha in linhas) {
        final chave = linha['key'] as String?;
        final valor = linha['value'] as String?;
        if (chave != null && valor != null) {
          _cacheMemoria[chave] = valor;
        }
      }
    } catch (e) {
      debugPrint('LocalSqliteService erro ao hidratar cache: $e');
    }
  }
}
