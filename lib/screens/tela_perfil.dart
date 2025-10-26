import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
// 🔹 ADICIONADO: Import para Geocoding e GeoPoint
import 'package:geocoding/geocoding.dart';

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

  String? _fotoUrl;
  // 🔹 ADICIONADO: Para armazenar a localização carregada/convertida
  GeoPoint? _localizacao;
  // 🔹 ADICIONADO: Estado de loading específico para geocoding ao salvar
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

  // LÓGICA DE CARREGAMENTO (agora inclui GeoPoint)
  Future<void> _carregarDadosDoUsuario() async {
    // ... (início da função como antes)
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
          _emailController.text = data['email'] ?? '';
          _fotoUrl = data['fotoUrl'];
          _telefoneController.text = data['telefone'] ?? '';
          _cpfController.text = data['cpf'] ?? '';
          // 🔹 ADICIONADO: Carrega o GeoPoint (se existir)
          _localizacao = data['localizacao'] as GeoPoint?;

          if (_isDriver) {
            _cnhController.text = data['cnh'] ?? '';
            // Se o endereço de texto não foi carregado, tenta pegar da localização (menos ideal)
             _enderecoController.text = data['endereco'] ?? ''; // Prioriza campo de texto

          } else {
             // Aluno também tem endereço e localização
             _enderecoController.text = data['endereco'] ?? '';
          }
        });
      }
    } catch (e) {
      // ... (erro handling)
       if (mounted) {
        setState(() {
          _errorMessage = "Erro ao carregar dados: $e";
        });
      }
    } finally {
      // ... (finally)
       if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  // LÓGICA DE SALVAMENTO (agora inclui Geocoding)
  Future<void> _salvarDados() async {
    // Validação básica do formulário (se houver um)
    // if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSavingWithGeocoding = true); // Ativa loading específico

    GeoPoint? novaLocalizacao;
    String enderecoTexto = _enderecoController.text.trim();

    // 1. Tenta fazer o Geocoding do endereço de texto
    if (enderecoTexto.isNotEmpty) {
      try {
        List<Location> locations = await locationFromAddress(enderecoTexto);
        if (locations.isNotEmpty) {
          novaLocalizacao = GeoPoint(locations.first.latitude, locations.first.longitude);
        } else {
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Não foi possível encontrar coordenadas para o endereço fornecido."), backgroundColor: Colors.orange),
            );
          }
        }
      } catch (e) {
        print("Erro de Geocoding: $e");
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Erro ao buscar localização: $e"), backgroundColor: Colors.red),
            );
          }
         // Decide se quer continuar salvando sem a localização ou parar
         // Aqui, vamos continuar salvando os outros dados
      }
    }

    // 2. Prepara os dados para salvar
    Map<String, dynamic> dadosParaSalvar = {
      "nome": _nomeController.text.trim(),
      "email": _emailController.text.trim(), // Email geralmente não é editável, mas ok
      "fotoUrl": _fotoUrl,
      "telefone": _telefoneController.text.trim(),
      "cpf": _cpfController.text.trim(),
      "endereco": enderecoTexto, // Salva o endereço como texto também
      // 🔹 ADICIONADO: Salva o GeoPoint convertido (ou null)
      "localizacao": novaLocalizacao,
    };

    if (_isDriver) {
      dadosParaSalvar.addAll({
        "cnh": _cnhController.text.trim(),
        // Endereço já está nos dados principais
      });
    } else {
       // Aluno não tem campos extras específicos aqui
    }

    // 3. Salva no Firestore
    try {
      await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(uid)
          .set(dadosParaSalvar, SetOptions(merge: true));

      if (mounted) {
        // Atualiza o estado local com a nova localização
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
        setState(() => _isSavingWithGeocoding = false); // Desativa loading específico
      }
    }
  }

  // LÓGICA DE UPLOAD DE FOTO (sem mudanças)
  Future<void> _escolherEUploadFoto() async {
    // ... (código existente)
     final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    // Usa o loading principal para upload de foto
    setState(() { _isLoading = true; });

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

      setState(() { _fotoUrl = downloadUrl; });

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
      // ... (erro handling)
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar foto: $e")),
        );
      }
    } finally {
       if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  // LÓGICA DE LOGOUT (sem mudanças)
  Future<void> _logout() async {
     // ... (código existente)
      try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil("/login", (route) => false);
      }
    } catch (e) {
      // ... (erro handling)
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao sair: $e")),
        );
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    // ... (sem mudanças)
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
    // Usa o loading principal para o carregamento inicial
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Meu Perfil")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      // ... (tela de erro)
       return Scaffold(
        appBar: AppBar(title: const Text("Meu Perfil")),
        body: Center(child: Text(_errorMessage!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Meu Perfil"),
        actions: [
          // 🔹 ADICIONADO: Mostra loading no botão Salvar
          _isSavingWithGeocoding
              ? const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ))),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: "Salvar",
                  // Desativa o botão enquanto salva
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
                  // ... (código do CircleAvatar como antes)
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
              decoration: const InputDecoration(labelText: "Telefone"),
              controller: _telefoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: "CPF"),
              controller: _cpfController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
             // 🔹 MOVIDO: Endereço agora é comum para ambos
             TextField(
                decoration: InputDecoration(
                  labelText: "Endereço Principal",
                   // Adiciona dica sobre geocoding
                  helperText: _isDriver ? "Usado para geolocalização." : "Usado para geolocalização.",
                  helperMaxLines: 2,
                ),
                controller: _enderecoController,
                maxLines: null, // Permite múltiplas linhas se necessário
              ),

            if (_isDriver) ...[
              _buildSectionTitle("Dados do Motorista"),
              TextField(
                decoration: const InputDecoration(labelText: "CNH"),
                controller: _cnhController,
                keyboardType: TextInputType.number,
              ),
              // Campo Endereço movido para a seção Pessoal
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

