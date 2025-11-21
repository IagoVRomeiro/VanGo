import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import 'tela_login.dart'; // Import para TelaLogin
import 'tela_notificacoes.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv


class PerfilScreen extends StatefulWidget {
  final String collectionPath;
  final bool showAppBar;

  const PerfilScreen({
    super.key,
    required this.collectionPath,
    this.showAppBar = true,
  });

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final String _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY']!;
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController();
  final TextEditingController _cnhController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();

  final _telefoneMaskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  final _cpfMaskFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  String? _fotoUrl;
  GeoPoint? _localizacao;
  String _initialAddress = "";
  bool _isSavingWithGeocoding = false;

  bool get _isDriver => widget.collectionPath == 'motoristas';

  @override
  void initState() {
    super.initState();
    _carregarDadosDoUsuario();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _enderecoController.dispose();
    _cnhController.dispose();
    _telefoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosDoUsuario() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Usuário não está logado.");
      }

      final profileDoc = await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(user.uid)
          .get();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (profileDoc.exists && userDoc.exists && mounted) {
        final profileData = profileDoc.data()!;
        final userData = userDoc.data()!;

        setState(() {
          _emailController.text = user.email ?? userData['email'] ?? '';
          _fotoUrl = userData['fotoUrl'];

          _nomeController.text = profileData['nome'] ?? '';
          _localizacao = profileData['localizacao'] as GeoPoint?;

          _telefoneController.text = profileData['telefone'] ?? '';
          _cpfController.text = profileData['cpf'] ?? '';
          
          _initialAddress = profileData['endereco'] ?? '';
          _enderecoController.text = _initialAddress;

          if (_isDriver) {
            _cnhController.text = profileData['cnh'] ?? '';
          }
        });
      } else if (mounted) {
        throw Exception("Documentos de perfil ou usuário não encontrados.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Erro ao carregar dados: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _salvarDados() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSavingWithGeocoding = true);

    // O GeoPoint já é atualizado pelo widget de autocomplete.
    // A geocodificação manual foi removida.
    String enderecoTexto = _enderecoController.text.trim();

    Map<String, dynamic> dadosParaSalvar = {
      "nome": _nomeController.text.trim(),
      "telefone": _telefoneMaskFormatter.getUnmaskedText(),
      "cpf": _cpfMaskFormatter.getUnmaskedText(),
      "endereco": enderecoTexto,
      "localizacao": _localizacao, // Usa o GeoPoint atualizado
    };

    if (_isDriver) {
      dadosParaSalvar.addAll({
        "cnh": _cnhController.text.trim(),
      });
    }

    try {
      await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(uid)
          .set(dadosParaSalvar, SetOptions(merge: true));

      if (mounted) {
        setState(() {
           _initialAddress = enderecoTexto;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Dados salvos com sucesso!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar dados: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingWithGeocoding = false);
      }
    }
  }

  Future<void> _escolherEUploadFoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("Usuário não está logado.");

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('$uid.jpg');

      if (kIsWeb) {
        await storageRef.putData(await pickedFile.readAsBytes());
      } else {
        await storageRef.putFile(File(pickedFile.path));
      }

      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users') 
          .doc(uid)
          .update({'fotoUrl': downloadUrl});

      if (mounted) {
        setState(() {
          _fotoUrl = downloadUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto de perfil atualizada!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao atualizar a foto: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TelaLogin()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao sair: $e")),
        );
      }
    }
  }
  
  void _goToNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TelaNotificacoes()),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color appBarColor = theme.colorScheme.primary; // Always primary color

    final Widget bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
            ? Center(child: Text(_errorMessage!))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _escolherEUploadFoto,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: _fotoUrl != null && _fotoUrl!.isNotEmpty
                              ? NetworkImage(_fotoUrl!)
                              : null,
                          child: _fotoUrl == null || _fotoUrl!.isEmpty
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Dados Pessoais"),
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(labelText: "Nome"),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: "Email"),
                      enabled: false,
                    ),
                    const SizedBox(height: 16),
                    GooglePlaceAutoCompleteTextField(
                      textEditingController: _enderecoController,
                      googleAPIKey: _apiKey,
                      inputDecoration: const InputDecoration(labelText: "Endereço"),
                      debounceTime: 400,
                      countries: const ["br"],
                      isLatLngRequired: true,
                      getPlaceDetailWithLatLng: (Prediction prediction) {
                        if (prediction.lat != null && prediction.lng != null) {
                           setState(() {
                            _localizacao = GeoPoint(double.parse(prediction.lat!), double.parse(prediction.lng!));
                          });
                        }
                      },
                      itemClick: (Prediction prediction) {
                        _enderecoController.text = prediction.description ?? '';
                        _enderecoController.selection = TextSelection.fromPosition(
                          TextPosition(offset: prediction.description?.length ?? 0),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telefoneController,
                      decoration: const InputDecoration(labelText: "Telefone"),
                      inputFormatters: [_telefoneMaskFormatter],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cpfController,
                      decoration: const InputDecoration(labelText: "CPF"),
                      inputFormatters: [_cpfMaskFormatter],
                    ),
                    if (_isDriver) ...[
                      _buildSectionTitle("Dados do Motorista"),
                      TextFormField(
                        controller: _cnhController,
                        decoration: const InputDecoration(labelText: "CNH"),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _isSavingWithGeocoding ? null : _salvarDados,
                      icon: _isSavingWithGeocoding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: const Text('SALVAR ALTERAÇÕES'),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _showDeleteConfirmationDialog,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Deletar Conta'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              );

    if (!widget.showAppBar) {
      return Material(child: bodyContent);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Meu Perfil"),
        backgroundColor: appBarColor,
        leading: IconButton(
          icon: const Icon(Icons.exit_to_app),
          tooltip: "Sair",
          onPressed: _logout,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: "Notificações",
            onPressed: _goToNotifications,
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Deletar Conta"),
          content: const Text(
              "Tem certeza que deseja deletar sua conta? Esta ação é irreversível e todos os seus dados serão perdidos."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Deletar", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o dialogo
                _deleteAccount();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nenhum usuário logado para deletar.")),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final uid = user.uid;

    try {
      // Inicia uma transação ou batch para garantir atomicidade
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Deleta o documento do perfil específico (motorista ou aluno)
      final profileDocRef = FirebaseFirestore.instance.collection(widget.collectionPath).doc(uid);
      batch.delete(profileDocRef);

      // 2. Deleta o documento da coleção 'users'
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
      batch.delete(userDocRef);

      // Aplica as deleções no Firestore
      await batch.commit();

      // 3. Deleta a foto de perfil do Firebase Storage, se existir
      try {
        final storageRef = FirebaseStorage.instance.ref().child('profile_pictures').child('$uid.jpg');
        await storageRef.delete();
      } on FirebaseException catch (e) {
        // Ignora o erro 'object-not-found', pois o usuário pode não ter uma foto
        if (e.code != 'object-not-found') {
          rethrow; // Propaga outros erros de storage
        }
      }

      // 4. Deleta o usuário do Firebase Authentication
      await user.delete();

      // 5. Navega para a tela de login
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Conta deletada com sucesso.")),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TelaLogin()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      if (e.code == 'requires-recent-login') {
        message = "Por segurança, faça login novamente para deletar sua conta.";
        // Desloga o usuário para forçar a re-autenticação
        await FirebaseAuth.instance.signOut();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
        );
        
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TelaLogin()),
          (route) => false,
        );
        return; // Retorna para não mostrar o snackbar genérico abaixo
      } else {
        message = "Erro ao deletar conta: ${e.message}";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ocorreu um erro inesperado: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
