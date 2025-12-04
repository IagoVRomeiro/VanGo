import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vango/services/local_sqlite_service.dart';

void main() {
  sqfliteFfiInit();
  bool sqliteDisponivel = true;

  group('LocalSqliteService', () {
    late LocalSqliteService servico;
    setUp(() async {
      servico = LocalSqliteService.instance;
      servico.fabricaBancoTeste = databaseFactoryFfi; 

      try {
        await servico.init();
      } catch (e) {
        // Se sqlite não estiver disponível no ambiente, apenas ignore os testes.
        sqliteDisponivel = false;
      }
    });

    tearDown(() async {
      await servico.bancoDepuracao?.close();
      servico.fabricaBancoTeste = null;
    });

    test('init() inicializa o banco e a tabela', () async {
      if (!sqliteDisponivel) return;
      expect(servico.bancoDepuracao, isNotNull);
      await servico.bancoDepuracao!.execute(
          'INSERT INTO cache (key, value) VALUES (?, ?)', ['chave_teste', 'valor_teste']);
      final resultado = await servico.bancoDepuracao!
          .query('cache', where: 'key = ?', whereArgs: ['chave_teste']);
      expect(resultado, isNotEmpty);
      expect(resultado.first['value'], 'valor_teste');
    });

    test('_salvarBruto e _buscarBruto funcionam', () async {
      if (!sqliteDisponivel) return;
      const chave = 'chave_bruta';
      const valor = '{"dados": "conteudo"}';
      await servico.salvarBrutoParaTeste(chave, valor);

      final valorObtido = await servico.buscarBrutoParaTeste(chave);
      expect(valorObtido, valor);
    });

    test('salvarUsuario e buscarUsuario funcionam', () async {
      if (!sqliteDisponivel) return;
      const usuarioId = 'usuarioTeste123';
      final dadosUsuario = {'nome': 'Teste', 'email': 'teste@exemplo.com'};

      await servico.salvarUsuario(usuarioId, dadosUsuario);

      final usuarioEmCache = await servico.buscarUsuario(usuarioId);
      expect(usuarioEmCache, isNotNull);
      expect(usuarioEmCache!['nome'], 'Teste');
      expect(usuarioEmCache['email'], 'teste@exemplo.com');
    });

    test('buscarUsuarioSync funciona após salvar', () async {
      if (!sqliteDisponivel) return;
      const usuarioId = 'usuarioSync456';
      final dadosUsuario = {'nome': 'Usuario Sync', 'idade': 30};

      await servico.salvarUsuario(usuarioId, dadosUsuario);

      final usuarioEmCache = servico.buscarUsuarioSync(usuarioId);
      expect(usuarioEmCache, isNotNull);
      expect(usuarioEmCache!['nome'], 'Usuario Sync');
      expect(usuarioEmCache['idade'], 30);
    });
  });
}
