// ignore_for_file: avoid_print

// 🎯 CORREÇÃO: Estava 'package.flutter', mudei para 'package:flutter'
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart';
// 1. IMPORTE O PACOTE DE MÁSCARA
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

// --- MODELO USUARIO (PARA REFERÊNCIA RÁPIDA) ---
enum UserRole {
  motorista,
  aluno,
  indefinido;

  static UserRole fromString(String? role) {
    return UserRole.values.firstWhere(
      (e) => e.name == role,
      orElse: () => UserRole.indefinido,
    );
  }
}

class Usuario {
  final String id;
  final String email;
  final UserRole role;
  final Timestamp? criadoEm;

  const Usuario({
    required this.id,
    required this.email,
    required this.role,
    this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role.name,
      'criadoEm': criadoEm ?? FieldValue.serverTimestamp(),
    };
  }

  factory Usuario.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception("Documento de usuário não encontrado ou está vazio.");
    }
    return Usuario(
      id: snapshot.id,
      email: data['email'] ?? '',
      role: UserRole.fromString(data['role']),
      criadoEm: data['criadoEm'],
    );
  }
}
// ------------------------------------------------

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

  // 2. DEFINA OS FORMATADORES DE MÁSCARA
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
  bool _isSavingWithGeocoding = false;

  bool get _isDriver => widget.collectionPath == 'motoristas';

  // Cores dinâmicas para AppBar
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

  Future<void> _carregarDadosDoUsuario() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Usuário não está logado.");
      }

      final doc = await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;

        setState(() {
          _nomeController.text = data['nome'] ?? '';
          _emailController.text = user.email ?? data['email'] ?? '';
          _fotoUrl = data['fotoUrl'];
          
          // Aplica o texto salvo (que pode ou não ter máscara)
          // O formatador irá tentar formatá-lo
          _telefoneController.text = data['telefone'] ?? '';
          _cpfController.text = data['cpf'] ?? '';

          _localizacao = data['localizacao'] as GeoPoint?;

          if (_isDriver) {
            _cnhController.text = data['cnh'] ?? '';
            _enderecoController.text = data['endereco'] ?? '';
          } else {
            _enderecoController.text = data['endereco'] ?? '';
          }
        });
      } else if (mounted) {
        throw Exception(
            "Documento de perfil não encontrado na coleção: ${widget.collectionPath}");
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

    GeoPoint? novaLocalizacao;
    String enderecoTexto = _enderecoController.text.trim();

    if (enderecoTexto.isNotEmpty) {
      try {
        List<Location> locations = await locationFromAddress(enderecoTexto);
        if (locations.isNotEmpty) {
          novaLocalizacao =
              GeoPoint(locations.first.latitude, locations.first.longitude);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      "Não foi possível encontrar coordenadas para o endereço fornecido."),
                  backgroundColor: Colors.orange),
            );
          }
        }
      } catch (e) {
        print("Erro de Geocoding: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Erro ao buscar localização: $e"),
                backgroundColor: Colors.red),
          );
        }
      }
    }

    // Pega o texto formatado pelo 'mask_formatter'
    Map<String, dynamic> dadosParaSalvar = {
      "nome": _nomeController.text.trim(),
      "email": _emailController.text.trim(),
      "fotoUrl": _fotoUrl,
      // Salva o texto já formatado
      "telefone": _telefoneController.text.trim(), 
      "cpf": _cpfController.text.trim(),
      "endereco": enderecoTexto,
      "localizacao": novaLocalizacao,
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
        setState(() => _localizacao = novaLocalizacao);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Dados salvos com sucesso!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar: $e")),
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

    setState(() {
      _isLoading = true;
    });

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

      setState(() {
        _fotoUrl = downloadUrl;
      });

      await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(uid)
          .update({'fotoUrl': downloadUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto de perfil atualizada com sucesso!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar foto: $e")),
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
            // 3. APLIQUE A MÁSCARA AO TEXTFIELD DE TELEFONE
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
            // 4. APLIQUE A MÁSCARA AO TEXTFIELD DE CPF
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
