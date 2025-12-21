import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Faz o upload de uma imagem de perfil de usuário.
  ///
  /// [uid] O ID do usuário.
  /// [imageFile] O arquivo de imagem a ser enviado (vindo do image_picker).
  /// Retorna a URL de download da imagem.
  Future<String> uploadProfileImage(String uid, XFile imageFile) async {
    try {
      final ref = _storage.ref().child('profile_pictures').child('$uid.jpg');
      return await _uploadFile(ref, imageFile);
    } catch (e) {
      // Em um app real, você poderia usar um logger mais robusto aqui.
      debugPrint('Erro ao fazer upload da imagem de perfil: $e');
      rethrow;
    }
  }

  /// Faz o upload da foto de uma van.
  ///
  /// [motoristaId] O ID do motorista proprietário da van.
  /// [placa] A placa da van, para garantir um nome de arquivo único.
  /// [imageFile] O arquivo de imagem a ser enviado.
  /// Retorna a URL de download da imagem.
  Future<String> uploadVanImage(
      String motoristaId, String placa, XFile imageFile) async {
    try {
      final ref = _storage
          .ref()
          .child('vans_pictures')
          .child('$motoristaId/$placa.jpg');
      return await _uploadFile(ref, imageFile);
    } catch (e) {
      debugPrint('Erro ao fazer upload da imagem da van: $e');
      rethrow;
    }
  }

  /// Deleta a foto de uma van no Firebase Storage.
  ///
  /// [motoristaId] O ID do motorista proprietário da van.
  /// [placa] A placa da van.
  Future<void> deleteVanImage(String motoristaId, String placa) async {
    // Se a placa estiver vazia, não há o que deletar.
    if (placa.isEmpty) return;
    try {
      final ref = _storage
          .ref()
          .child('vans_pictures')
          .child('$motoristaId/$placa.jpg');
      await _deleteFile(ref);
    } catch (e) {
      debugPrint('Erro ao deletar a imagem da van: $e');
      // Não relança o erro para não impedir a exclusão do restante dos dados da van.
    }
  }

  /// Lida com a lógica de upload real, abstraindo a diferença entre web e mobile.
  ///
  /// [ref] A referência do Firebase Storage para onde o arquivo será enviado.
  /// [imageFile] O arquivo de imagem a ser enviado.
  /// Retorna a URL de download após o upload.
  Future<String> _uploadFile(Reference ref, XFile imageFile) async {
    // A metadata é a chave para o Firebase Extension de redimensionamento de imagem funcionar.
    final metadata = SettableMetadata(contentType: 'image/jpeg');

    UploadTask uploadTask;

    if (kIsWeb) {
      final bytes = await imageFile.readAsBytes();
      uploadTask = ref.putData(bytes, metadata);
    } else {
      uploadTask = ref.putFile(File(imageFile.path), metadata);
    }

    // Aguarda o upload ser concluído
    await uploadTask;

    // Retorna a URL de download
    return await ref.getDownloadURL();
  }

  /// Deleta um arquivo do storage.
  Future<void> _deleteFile(Reference ref) async {
    try {
      await ref.delete();
    } on FirebaseException catch (e) {
      // O arquivo não existir é um caso de sucesso esperado ao deletar.
      if (e.code == 'object-not-found') {
        debugPrint('Arquivo não encontrado no storage, considerando como sucesso.');
        return;
      }
      // Se for outro erro, loga mas não relança para não quebrar a operação principal.
      debugPrint('Erro ao deletar arquivo do storage: $e');
    }
  }
}
