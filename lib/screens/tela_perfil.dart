// lib/screens/tela_perfil.dart - CORRIGIDO ✅

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

// Imports relativos para a pasta 'models'
import '../models/motorista.dart';
import '../models/aluno.dart';

// O resto do seu código da TelaPerfil...
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
  final TextEditingController _universidadeController = TextEditingController();
  final TextEditingController _veiculoController = TextEditingController();
  final TextEditingController _placaController = TextEditingController();
  final TextEditingController _cnhController = TextEditingController();
  final TextEditingController _serieController = TextEditingController();

  // Preferências e Foto
  bool _notificacoesAtivas = true;
  bool _receberEmails = false;
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
    _universidadeController.dispose();
    _veiculoController.dispose();
    _placaController.dispose();
    _cnhController.dispose();
    _serieController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // LÓGICA DE CARREGAMENTO (AJUSTADA PARA fromSnapshot)
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
          _notificacoesAtivas = data['notificacoesAtivas'] ?? true;
          _receberEmails = data['receberEmails'] ?? false;
          _fotoUrl = data['fotoUrl'];

          if (_isDriver) {
            // Campos específicos do Motorista
            _veiculoController.text = data['veiculo'] ?? '';
            _placaController.text = data['placa'] ?? '';
            _cnhController.text = data['cnh'] ?? '';
            // Outros campos do aluno não são relevantes, mas universidade é
            // um campo de texto que poderia ser usado por exemplo como endereço
            _universidadeController.text = data['endereco'] ?? ''; 
          } else {
            // Campos específicos do Aluno (usando universidade como escola/escola)
            _universidadeController.text = data['escola'] ?? '';
            _serieController.text = data['serie'] ?? '';
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
  // LÓGICA DE SALVAMENTO (USANDO MODELOS E toMap)
  // -------------------------------------------------------------------

  Future<void> _salvarDados() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      Map<String, dynamic> dadosParaSalvar = {
        "nome": _nomeController.text.trim(),
        "email": _emailController.text.trim(),
        "notificacoesAtivas": _notificacoesAtivas,
        "receberEmails": _receberEmails,
        "fotoUrl": _fotoUrl,
      };

      if (_isDriver) {
        // Usa o modelo Motorista para garantir a consistência
        dadosParaSalvar.addAll({
          "veiculo": _veiculoController.text.trim(),
          "placa": _placaController.text.trim(),
          "cnh": _cnhController.text.trim(),
          "endereco": _universidadeController.text.trim(), // Reutiliza o campo para Endereço
        });
      } else {
        // Usa o modelo Aluno para garantir a consistência
        // Nota: Outros campos como idade/localizacao seriam salvos em telas específicas
        dadosParaSalvar.addAll({
          "escola": _universidadeController.text.trim(),
          "serie": _serieController.text.trim(),
        });
      }

      await FirebaseFirestore.instance.collection(widget.collectionPath).doc(uid).set(
        dadosParaSalvar, 
        SetOptions(merge: true)
      );

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
  // LÓGICA DE UPLOAD DE FOTO (JÁ ESTAVA CORRETA)
  // -------------------------------------------------------------------

  Future<void> _escolherEUploadFoto() async {
    // ... (função _escolherEUploadFoto permanece a mesma)
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

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

      await storageRef.putFile(File(pickedFile.path));
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
        Navigator.of(context).pushNamedAndRemoveUntil("/login", (route) => false);
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
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                      : const AssetImage("assets/images/user_placeholder.png") as ImageProvider, // Placeholder
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

            if (_isDriver) ...[
              _buildSectionTitle("Informações do Veículo e Endereço"),
              TextField(
                decoration: const InputDecoration(labelText: "Veículo (Modelo)"),
                controller: _veiculoController,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(labelText: "Placa"),
                controller: _placaController,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(labelText: "CNH"),
                controller: _cnhController,
                keyboardType: TextInputType.number,
              ),
               const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(labelText: "Endereço Principal"),
                controller: _universidadeController, // Reutiliza o controlador
              ),
            ] else ...[
              _buildSectionTitle("Dados Acadêmicos"),
              TextField(
                decoration: const InputDecoration(labelText: "Escola"),
                controller: _universidadeController, // Reutiliza o controlador
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(labelText: "Série / Ano"),
                controller: _serieController,
              ),
              // Outros campos do aluno (ex: Contato do Responsável) seriam adicionados aqui
            ],

            _buildSectionTitle("Preferências"),
            SwitchListTile(
              title: const Text("Ativar notificações"),
              value: _notificacoesAtivas,
              onChanged: (bool novoValor) {
                setState(() => _notificacoesAtivas = novoValor);
              },
            ),
            SwitchListTile(
              title: const Text("Receber emails promocionais"),
              value: _receberEmails,
              onChanged: (bool? novoValor) {
                setState(() => _receberEmails = novoValor ?? false);
              },
            ),
             const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}