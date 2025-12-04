import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class PermissionService {
  /// Checa e solicita permissão de localização.
  /// Retorna 'true' se a permissão for concedida, 'false' caso contrário.
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Checa se o serviço de localização está ativo
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Idealmente, aqui você mostraria um diálogo para o usuário ativar os serviços.
      // Por simplicidade, vamos apenas retornar false e logar.
      debugPrint("Serviço de localização desativado.");
      return false;
    }

    // 2. Checa o status da permissão
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 3. Se negada, solicita a permissão
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("Permissão de localização negada.");
        return false;
      }
    }

    // 4. Checa se a permissão foi negada permanentemente
    if (permission == LocationPermission.deniedForever) {
      debugPrint("Permissão de localização negada permanentemente.");
      // Idealmente, aqui você mostraria um diálogo explicando como
      // habilitar a permissão manualmente nas configurações do app.
      return false;
    }

    // 5. Se chegou até aqui, a permissão foi concedida
    return true;
  }
}
