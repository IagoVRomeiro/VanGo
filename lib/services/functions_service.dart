import 'package:cloud_functions/cloud_functions.dart';

/// Encapsula o acesso às Cloud Functions, fixando a região primária
/// e fazendo fallback para a instância padrão se a função não for encontrada.
class FunctionsService {
  FunctionsService._();
  static final FunctionsService instance = FunctionsService._();

  // Ajuste a região conforme a implantação das suas funções.
  static const String _region = 'southamerica-east1';

  FirebaseFunctions get _primary => FirebaseFunctions.instanceFor(region: _region);
  FirebaseFunctions get _default => FirebaseFunctions.instance;

  Future<HttpsCallableResult<R>> call<R>(
    String name, {
    Map<String, dynamic>? data,
  }) async {
    try {
      return await _primary.httpsCallable(name).call<R>(data ?? <String, dynamic>{});
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        return await _default.httpsCallable(name).call<R>(data ?? <String, dynamic>{});
      }
      rethrow;
    }
  }
}
