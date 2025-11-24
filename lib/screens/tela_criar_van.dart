import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vango/models/van.dart'; // Seu modelo de Van (que espera 'vanFotoUrl')
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io'; // Para 'File' (mobile)
import 'package:flutter/foundation.dart' show kIsWeb; // Para 'kIsWeb'
import 'dart:typed_data';

class CadastrarVanScreen extends StatefulWidget {
  const CadastrarVanScreen({super.key});

  @override
  State<CadastrarVanScreen> createState() => _CadastrarVanScreenState();
}

class _CadastrarVanScreenState extends State<CadastrarVanScreen> {
  final _formKey = GlobalKey<FormState>();

  final _placaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _marcaController = TextEditingController();
  final _anoController = TextEditingController();
  final _capacidadeController = TextEditingController();
  final _corController = TextEditingController();

  // Variáveis para o upload de imagem
  XFile? _imageFile; // Para mobile
  Uint8List? _imageBytes; // Para web
  bool _isUploading = false; // Para feedback de UI

  bool _isLoading = false;

  @override
  void dispose() {
    _placaController.dispose();
    _modeloController.dispose();
    _marcaController.dispose();
    _anoController.dispose();
    _capacidadeController.dispose();
    _corController.dispose();
    super.dispose();
  }

  /// Função para escolher a imagem
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    if (kIsWeb) {
      _imageBytes = await pickedFile.readAsBytes();
      _imageFile = null; // Garante que apenas um seja usado
    } else {
      _imageFile = pickedFile;
      _imageBytes = null; // Garante que apenas um seja usado
    }
    setState(() {}); // Atualiza a UI para mostrar a prévia
  }

  /// Função para fazer o upload da foto para o Storage
  /// Retorna a URL do download ou null se nenhuma foto foi escolhida.
  Future<String?> _uploadFoto(String motoristaId, String placa) async {
    // Se nenhuma imagem foi escolhida, retorna nulo
    if (_imageFile == null && _imageBytes == null) {
      return null;
    }

    setState(() => _isUploading = true);

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('vans_pictures')
          .child('$motoristaId/$placa.jpg');

      // Upload baseado na plataforma
      if (kIsWeb) {
        await storageRef.putData(_imageBytes!);
      } else {
        await storageRef.putFile(File(_imageFile!.path));
      }

      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao enviar foto: $e'),
              backgroundColor: Colors.red),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  /// 🔹 FUNÇÃO _salvarVan ATUALIZADA 🔹
  Future<void> _salvarVan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final motoristaId = FirebaseAuth.instance.currentUser?.uid;
    if (motoristaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro: Motorista não autenticado.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 1. Faz o upload da foto ANTES de salvar no Firestore
    final String? fotoUrl = await _uploadFoto(
      motoristaId,
      _placaController.text.trim(),
    );

    // 2. Cria o objeto Van com os dados
    final van = Van(
      id: '', // O Firestore irá gerar um ID se usarmos .add()
      placa: _placaController.text.trim(),
      marca: _marcaController.text.trim(),
      modelo: _modeloController.text.trim(),
      ano: int.parse(_anoController.text),
      capacidade: int.parse(_capacidadeController.text),
      cor: _corController.text.trim(),
      status: StatusVan.disponivel, // Padrão 'disponivel'
      motoristaId: motoristaId,
      
      // 🔹 CORRIGIDO: Usa o parâmetro 'vanFotoUrl' do modelo Van
      vanFotoUrl: fotoUrl,
    );

    try {
      // Salva a van na coleção principal 'vans'
      final vanDoc =
          await FirebaseFirestore.instance.collection('vans').add(van.toMap());

      // 🔹 CORRIGIDO: Atualiza o motorista APENAS com o ID da van.
      // Isso evita a duplicação de dados (placa, veiculo, etc.)
      // que foi o motivo da nossa primeira refatoração.
      await FirebaseFirestore.instance
          .collection('motoristas')
          .doc(motoristaId)
          .update({
        'vanId': vanDoc.id, // Salva a referência da van
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Van cadastrada com sucesso!'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao cadastrar van: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.red,
              onPrimary: Colors.white,
            ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cadastrar Nova Van'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                bottom: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Widget de upload de imagem
                        _buildImagePicker(),
                        const SizedBox(height: 16),
                        _buildTextField(_placaController, 'Placa (ex: ABC1D23)'),
                        _buildTextField(
                            _marcaController, 'Marca (ex: Mercedes-Benz)'),
                        _buildTextField(_modeloController, 'Modelo (ex: Sprinter)'),
                        _buildTextField(_corController, 'Cor'),
                        Row(
                          children: [
                            Expanded(
                                child: _buildTextField(_anoController, 'Ano',
                                    keyboardType: TextInputType.number)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildTextField(
                                    _capacidadeController, 'Capacidade',
                                    keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _salvarVan,
                          icon: const Icon(Icons.save),
                          label: const Text('SALVAR VAN'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Widget para o seletor de imagem
  Widget _buildImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: 150,
          width: 250,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_imageBytes != null)
                // Prévia (Web)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _imageBytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                )
              else if (_imageFile != null)
                // Prévia (Mobile)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_imageFile!.path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                )
              else
                // Placeholder
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo,
                        color: Colors.grey.shade700, size: 40),
                    const SizedBox(height: 8),
                    Text('Foto da Van',
                        style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              if (_isUploading)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper para construir os TextFields
  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text,
      bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Este campo é obrigatório.';
          }
          if (keyboardType == TextInputType.number &&
              isRequired &&
              (value == null || int.tryParse(value) == null)) {
            return 'Por favor, insira um número válido.';
          }
          return null;
        },
      ),
    );
  }
}