import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vango/services/local_sqlite_service.dart';

/// Serviço simples para cache local usando Hive.
/// Mantém caixas para usuários, rotas e alunos vinculados.
class LocalCacheService {
  static final LocalCacheService instance = LocalCacheService._();
  LocalCacheService._();

  static const _usersBox = 'users_cache';
  static const _rotasBox = 'rotas_cache';
  static const _alunosBox = 'alunos_cache';
  static const _rotaAtualKey = 'rota_atual';

  Future<void> init() async {
    // No web, Hive já usa storage padrão; no mobile, usar diretório de app.
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);
    await Future.wait([
      Hive.openBox<String>(_usersBox),
      Hive.openBox<String>(_rotasBox),
      Hive.openBox<String>(_alunosBox),
    ]);
    await LocalSqliteService.instance.init();
  }

  Future<void> cacheUser(String userId, Map<String, dynamic> data) async {
    final box = Hive.box<String>(_usersBox);
    await box.put(userId, jsonEncode(data));
    await LocalSqliteService.instance.salvarUsuario(userId, data);
  }

  Map<String, dynamic>? getCachedUser(String userId) {
    final box = Hive.box<String>(_usersBox);
    final raw = box.get(userId);
    if (raw != null) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return LocalSqliteService.instance.buscarUsuarioSync(userId);
  }

  Future<void> cacheRotas(List<Map<String, dynamic>> rotas) async {
    final box = Hive.box<String>(_rotasBox);
    await box.put('lista', jsonEncode(rotas));
    await LocalSqliteService.instance.salvarRotas(rotas);
  }

  List<Map<String, dynamic>> getCachedRotas() {
    final box = Hive.box<String>(_rotasBox);
    final raw = box.get('lista');
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    // best effort fallback to SQLite
    return LocalSqliteService.instance.buscarRotasSync();
  }

  Future<void> cacheRotaAtual(Map<String, dynamic> rota) async {
    final box = Hive.box<String>(_rotasBox);
    await box.put(_rotaAtualKey, jsonEncode(rota));
    await LocalSqliteService.instance.salvarRotaAtual(rota);
  }

  Map<String, dynamic>? getCachedRotaAtual() {
    final box = Hive.box<String>(_rotasBox);
    final raw = box.get(_rotaAtualKey);
    if (raw != null) {
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    return LocalSqliteService.instance.buscarRotaAtualSync();
  }

  Future<void> cacheAlunos(List<Map<String, dynamic>> alunos) async {
    final box = Hive.box<String>(_alunosBox);
    await box.put('lista', jsonEncode(alunos));
    await LocalSqliteService.instance.salvarAlunos(alunos);
  }

  List<Map<String, dynamic>> getCachedAlunos() {
    final box = Hive.box<String>(_alunosBox);
    final raw = box.get('lista');
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    }
    return LocalSqliteService.instance.buscarAlunosSync();
  }
}
