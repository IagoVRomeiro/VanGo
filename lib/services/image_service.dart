import 'package:flutter/foundation.dart';

class ImageService {
  /// Retorna a URL de uma imagem redimensionada pela extensão do Firebase.
  ///
  /// Se a URL original for nula ou vazia, retorna nulo.
  /// A função assume que a extensão "Resize Images" está instalada e
  /// configurada para criar imagens com o sufixo "_400x400".
  ///
  /// Exemplo:
  /// Original: ".../profile_pictures%2Fuser_id.jpg?alt=media&token=..."
  /// Retorna: ".../profile_pictures%2Fuser_id_400x400.jpg?alt=media&token=..."
  static String? getResizedUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) {
      return null;
    }

    // O tamanho padrão que vamos usar em todo o app.
    // Isso deve corresponder à configuração da extensão no Firebase.
    const String suffix = '_400x400';

    try {
      // Decodifica a URL para lidar com caracteres como '%2F' (a barra '/')
      final decodedUrl = Uri.decodeComponent(originalUrl);
      
      // Encontra a posição do final do nome do arquivo (antes da extensão e dos parâmetros)
      final jpgIndex = decodedUrl.lastIndexOf('.jpg?');
      final pngIndex = decodedUrl.lastIndexOf('.png?');
      final jpegIndex = decodedUrl.lastIndexOf('.jpeg?');
      final webpIndex = decodedUrl.lastIndexOf('.webp?');

      int extensionIndex = -1;
      if (jpgIndex != -1) {
        extensionIndex = jpgIndex;
      } else if (pngIndex != -1) {
        extensionIndex = pngIndex;
      } else if (jpegIndex != -1) {
        extensionIndex = jpegIndex;
      } else if (webpIndex != -1) {
        extensionIndex = webpIndex;
      }
      
      // Se encontrou uma extensão de imagem conhecida antes dos parâmetros
      if (extensionIndex != -1) {
        final baseUrl = decodedUrl.substring(0, extensionIndex);
        final queryParams = decodedUrl.substring(extensionIndex);
        
        // Reconstrói a URL com o sufixo e re-codifica para ser uma URL válida
        return Uri.encodeFull('$baseUrl$suffix$queryParams');
      }

      // Se não encontrou um padrão esperado, retorna a URL original por segurança.
      return originalUrl;

    } catch (e) {
      // Em caso de erro na manipulação da string, retorna a original.
      debugPrint('Erro ao gerar URL redimensionada: $e');
      return originalUrl;
    }
  }
}
