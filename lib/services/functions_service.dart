import 'package:cloud_functions/cloud_functions.dart';

/// Encapsula o acesso às Cloud Functions, fixando a região primária
/// e fazendo fallback para outras regiões conhecidas se a função não for encontrada.
class FunctionsService {
  FunctionsService._();
  static final FunctionsService instance = FunctionsService._();

  static const List<String> _regions = ['us-central1', 'southamerica-east1'];



  Future<HttpsCallableResult<R>> call<R>(
    String name, {
    Map<String, dynamic>? data,
  }) async {
    FirebaseFunctionsException? notFoundException;
    for (final region in _regions) {
      try {
        final instance = FirebaseFunctions.instanceFor(region: region);
        return await instance.httpsCallable(name).call<R>(data ?? <String, dynamic>{});
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'not-found') {
          notFoundException = e;
          continue; // Try the next region
        }
        rethrow; // Re-throw other types of exceptions
      }
    }
    // If we've exhausted all regions and the function was consistently not found
    if (notFoundException != null) {
      throw notFoundException;
    }
    // This case should ideally not be reached if notFoundException is handled
    throw FirebaseFunctionsException(
        code: 'unknown', message: 'Function $name not found in any specified region.');
  }
}
