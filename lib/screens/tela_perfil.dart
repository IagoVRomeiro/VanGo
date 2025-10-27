// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

// (Cole o modelo 'Usuario' ATUALIZADO aqui)

class PerfilScreen extends StatefulWidget {
  final String collectionPath;

  const PerfilScreen({
    super.key,
    required this.collectionPath,
  });

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
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

  String? _fotoUrl; // Vem da coleção 'users'
  GeoPoint? _localizacao; // Vem da 'collectionPath'
  String _initialAddress = ""; // 🔹 Para checagem de geocoding
  bool _isSavingWithGeocoding = false;

  bool get _isDriver => widget.collectionPath == 'motoristas';

  Color get _appBarColor => _isDriver ? const Color(0xFFE53935) : Colors.amber;
  Color get _foregroundColor => Colors.white;

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

  /// 🔹 ATUALIZADO: Carrega de 'users' e 'collectionPath'
  Future<void> _carregarDadosDoUsuario() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Usuário não está logado.");
      }

      // 1. Busca dados do perfil (nome, cpf, telefone, etc.)
      final profileDoc = await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(user.uid)
          .get();

      // 2. Busca dados do usuário (email, fotoUrl)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (profileDoc.exists && userDoc.exists && mounted) {
        final profileData = profileDoc.data()!;
        final userData = userDoc.data()!;

        setState(() {
          // Dados de 'users'
          _emailController.text = user.email ?? userData['email'] ?? '';
          _fotoUrl = userData['fotoUrl']; // ⬅️ CORRETO

          // Dados de 'motoristas' / 'alunos'
          _nomeController.text = profileData['nome'] ?? '';
          _localizacao = profileData['localizacao'] as GeoPoint?;

          // Aplica máscaras aos dados salvos (brutos ou formatados)
          _telefoneController.text = profileData['telefone'] ?? '';
          _cpfController.text = profileData['cpf'] ?? '';
          
          _initialAddress = profileData['endereco'] ?? ''; // ⬅️ Guarda o endereço inicial
          _enderecoController.text = _initialAddress;

          if (_isDriver) {
            _cnhController.text = profileData['cnh'] ?? '';
          }
        });
      } else if (mounted) {
        throw Exception(
            "Documentos de perfil ou usuário não encontrados.");
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

  /// 🔹 ATUALIZADO: Salva dados brutos e geocoding eficiente
  Future<void> _salvarDados() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSavingWithGeocoding = true);

    GeoPoint? novaLocalizacao = _localizacao; // Mantém a localização antiga por padrão
    String enderecoTexto = _enderecoController.text.trim();

    // 🔹 CORREÇÃO: Só busca geocoding se o endereço mudou
    if (enderecoTexto.isNotEmpty && enderecoTexto != _initialAddress) {
      try {
        List<Location> locations = await locationFromAddress(enderecoTexto);
        if (locations.isNotEmpty) {
          novaLocalizacao =
              GeoPoint(locations.first.latitude, locations.first.longitude);
        } else {
           // (Aviso de endereço não encontrado...)
        }
      } catch (e) {
         // (Tratamento de erro de geocoding...)
      }
    }

    // 🔹 CORREÇÃO: Salva os dados brutos (sem máscara)
    Map<String, dynamic> dadosParaSalvar = {
      "nome": _nomeController.text.trim(),
      // "email" não precisa ser salvo aqui, já está em 'users'
      // "fotoUrl" não é salvo aqui, é salvo em 'users'
      "telefone": _telefoneMaskFormatter.getUnmaskedText(), // ⬅️ CORRETO
      "cpf": _cpfMaskFormatter.getUnmaskedText(), // ⬅️ CORRETO
      "endereco": enderecoTexto,
      "localizacao": novaLocalizacao,
    };

    if (_isDriver) {
      dadosParaSalvar.addAll({
        "cnh": _cnhController.text.trim(),
      });
    }

    try {
      // Salva apenas os dados do perfil na 'collectionPath'
      await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(uid)
          .set(dadosParaSalvar, SetOptions(merge: true));

      if (mounted) {
        setState(() {
           _localizacao = novaLocalizacao;
           _initialAddress = enderecoTexto; // Atualiza o endereço inicial
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Dados salvos com sucesso!")),
        );
      }
    } catch (e) {
       // (Tratamento de erro...)
    } finally {
      if (mounted) {
        setState(() => _isSavingWithGeocoding = false);
      }
    }
  }

  /// 🔹 ATUALIZADO: Salva a foto na coleção 'users'
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
          .child('profile_pictures') // Pasta central de fotos de perfil
          .child('$uid.jpg');

      if (kIsWeb) {
        await storageRef.putData(await pickedFile.readAsBytes());
      } else {
        await storageRef.putFile(File(pickedFile.path));
      }

      final downloadUrl = await storageRef.getDownloadURL();

      // 🔹 CORREÇÃO: Atualiza o documento na coleção 'users'
      await FirebaseFirestore.instance
          .collection('users') 
          .doc(uid)
          .update({'fotoUrl': downloadUrl});

      if (mounted) {
        setState(() {
          _fotoUrl = downloadUrl; // Atualiza a UI localmente
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto de perfil atualizada!")),
        );
      }
    } catch (e) {
      // (Tratamento de erro...)
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    // (Seu código de logout está perfeito, sem mudanças)
     try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil("/login", (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao sair: $e")),
        );
      }
    }
  }
  
  // (Restante do seu código: _buildSectionTitle, build(), etc.)
  // (O seu 'build' está ótimo e não precisa de mudanças)
  
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
            title: const Text("Meu Perfil"),
            backgroundColor: _appBarColor,
            foregroundColor: _foregroundColor),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
            title: const Text("Meu Perfil"),
            backgroundColor: _appBarColor,
            foregroundColor: _foregroundColor),
        body: Center(child: Text(_errorMessage!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Meu Perfil"),
        backgroundColor: _appBarColor,
        foregroundColor: _foregroundColor,
        actions: [
          _isSavingWithGeocoding
              ? Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _foregroundColor,
                          ))),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: "Salvar",
                  onPressed: _isSavingWithGeocoding ? null : _salvarDados,
                ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Sair",
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                      : const NetworkImage(
                              'https://placehold.co/100x100/EFEFEF/AAAAAA?text=Sem+Foto')
                          as ImageProvider,
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.edit, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            _buildSectionTitle("Dados Pessoais"),
            TextField(
              decoration: const InputDecoration(labelText: "Nome"),
              controller: _nomeController,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: "Email"),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: false,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                labelText: "Telefone",
                hintText: "(00) 00000-0000",
              ),
              controller: _telefoneController,
              keyboardType: TextInputType.number,
              inputFormatters: [_telefoneMaskFormatter],
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                labelText: "CPF",
                hintText: "000.000.000-00",
              ),
              controller: _cpfController,
              keyboardType: TextInputType.number,
              inputFormatters: [_cpfMaskFormatter],
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: "Endereço Principal",
                helperText: _isDriver
                    ? "Usado para geolocalização."
                    : "Usado para geolocalização.",
                helperMaxLines: 2,
              ),
              controller: _enderecoController,
              maxLines: null,
            ),
            if (_isDriver) ...[
              _buildSectionTitle("Dados do Motorista"),
              TextField(
                decoration: const InputDecoration(labelText: "CNH"),
                controller: _cnhController,
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}