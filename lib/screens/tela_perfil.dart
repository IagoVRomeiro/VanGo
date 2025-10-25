import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io'; // Necessário para o 'File' no mobile
import 'package:flutter/foundation.dart' show kIsWeb; // Necessário para detectar Web

class PerfilScreen extends StatefulWidget {
  final String collectionPath; // 'motoristas' ou 'alunos'

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

  // Controladores para os campos de texto
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController(); // Endereço (Motorista)
  final TextEditingController _cnhController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController(); // 🔹 ADICIONADO
  final TextEditingController _cpfController = TextEditingController(); // 🔹 ADICIONADO

  // Campos removidos: _veiculoController, _serieController, _notificacoesAtivas, _receberEmails

  String? _fotoUrl;

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
    _telefoneController.dispose(); // 🔹 ADICIONADO
    _cpfController.dispose(); // 🔹 ADICIONADO
    super.dispose();
  }

  // -------------------------------------------------------------------
  // LÓGICA DE CARREGAMENTO
  // -------------------------------------------------------------------

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
          _emailController.text = data['email'] ?? '';
          _fotoUrl = data['fotoUrl'];
          _telefoneController.text = data['telefone'] ?? ''; // 🔹 ADICIONADO
          _cpfController.text = data['cpf'] ?? ''; // 🔹 ADICIONADO

          // Campos de preferências e outros foram removidos

          if (_isDriver) {
            // Campos específicos do Motorista
            _cnhController.text = data['cnh'] ?? '';
            _enderecoController.text = data['endereco'] ?? '';
          } else {
            // Campos do Aluno (nenhum campo extra além dos pessoais)
          }
        });
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

  // -------------------------------------------------------------------
  // LÓGICA DE SALVAMENTO
  // -------------------------------------------------------------------

  Future<void> _salvarDados() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      Map<String, dynamic> dadosParaSalvar = {
        "nome": _nomeController.text.trim(),
        "email": _emailController.text.trim(),
        "fotoUrl": _fotoUrl,
        "telefone": _telefoneController.text.trim(), // 🔹 ADICIONADO
        "cpf": _cpfController.text.trim(), // 🔹 ADICIONADO
        // Campos de preferências removidos
      };

      if (_isDriver) {
        dadosParaSalvar.addAll({
          "cnh": _cnhController.text.trim(),
          "endereco": _enderecoController.text.trim(),
          // "veiculo" removido
        });
      } else {
        // "escola" e "serie" removidos
      }

      await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(uid)
          .set(dadosParaSalvar, SetOptions(merge: true));

      if (mounted) {
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
    }
  }

  // -------------------------------------------------------------------
  // LÓGICA DE UPLOAD DE FOTO (CORRIGIDA PARA WEB E MOBILE)
  // -------------------------------------------------------------------

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

      // --- CORREÇÃO PARA WEB (Platform error) ---
      if (kIsWeb) {
        // Flutter Web usa putData com bytes
        await storageRef.putData(await pickedFile.readAsBytes());
      } else {
        // Mobile (Android/iOS) usa putFile com o caminho do dart:io
        await storageRef.putFile(File(pickedFile.path));
      }
      // --- FIM DA CORREÇÃO ---

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

  // -------------------------------------------------------------------
  // LÓGICA DE LOGOUT
  // -------------------------------------------------------------------

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        // Redireciona para a tela de login (assume que a rota existe)
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
        appBar: AppBar(title: const Text("Meu Perfil")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Meu Perfil")),
        body: Center(child: Text(_errorMessage!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Meu Perfil"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: "Salvar",
            onPressed: _salvarDados,
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
                          as ImageProvider, // Placeholder da WEB
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
              enabled: false, // Email geralmente não é editável
            ),
            const SizedBox(height: 10),
            TextField( // 🔹 ADICIONADO
              decoration: const InputDecoration(labelText: "Telefone"),
              controller: _telefoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextField( // 🔹 ADICIONADO
              decoration: const InputDecoration(labelText: "CPF"),
              controller: _cpfController,
              keyboardType: TextInputType.number,
            ),
            if (_isDriver) ...[
              _buildSectionTitle("Dados do Motorista"), // 🔹 TÍTULO MUDADO
              // Campo "Veículo" removido
              TextField(
                decoration: const InputDecoration(labelText: "CNH"),
                controller: _cnhController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration:
                    const InputDecoration(labelText: "Endereço Principal"),
                controller: _enderecoController,
              ),
            ],
            // Seção "Dados Acadêmicos" (para Aluno) removida
            // Seção "Preferências" removida
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

