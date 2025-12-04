import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vango/models/van.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // Para 'File' (mobile)
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:vango/widgets/neon_app_bar.dart';
import 'package:vango/services/storage_service.dart'; // Import do novo serviço
import 'tela_notificacoes.dart';

class CadastrarVanScreen extends StatefulWidget {
  final Van? van;
  const CadastrarVanScreen({super.key, this.van});

  @override
  State<CadastrarVanScreen> createState() => _CadastrarVanScreenState();
}

class _CadastrarVanScreenState extends State<CadastrarVanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = StorageService(); // Instância do serviço

  final _placaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _marcaController = TextEditingController();
  final _anoController = TextEditingController();
  final _capacidadeController = TextEditingController();
  final _corController = TextEditingController();

  XFile? _imageFile;
  bool _isUploading = false;
  bool _isLoading = false;
  bool _isEditMode = false;
  String? _vanId;
  String? _fotoUrlExistente;

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

  @override
  void initState() {
    super.initState();
    _popularDadosSeEdicao();
  }

  Future<bool> _requestGalleryPermission() async {
    if (kIsWeb) {
      return true;
    }

    PermissionStatus status;
    if (Platform.isIOS) {
      status = await Permission.photos.request();
    } else {
      status = await Permission.storage.request();
      if (!status.isGranted && !status.isPermanentlyDenied) {
        status = await Permission.photos.request();
      }
    }

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permissão para acessar a galeria foi negada permanentemente. Ajuste nas configurações do aparelho.',
          ),
        ),
      );
      await openAppSettings();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão para acessar a galeria negada.')),
      );
    }

    return false;
  }

  Future<void> _pickImage() async {
    final hasPermission = await _requestGalleryPermission();
    if (!hasPermission) return;

    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  void _popularDadosSeEdicao() {
    final van = widget.van;
    if (van == null) return;
    _isEditMode = true;
    _vanId = van.id;
    _placaController.text = van.placa;
    _modeloController.text = van.modelo;
    _marcaController.text = van.marca;
    _anoController.text = van.ano.toString();
    _capacidadeController.text = van.capacidade.toString();
    _corController.text = van.cor;
    _fotoUrlExistente = van.vanFotoUrl;
  }

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

    setState(() {
      _isLoading = true;
      _isUploading = _imageFile != null;
    });

    String? fotoUrl = _fotoUrlExistente;
    try {
      // 1. Faz o upload da foto, se uma foi escolhida
      if (_imageFile != null) {
        fotoUrl = await _storageService.uploadVanImage(
          motoristaId,
          _placaController.text.trim(),
          _imageFile!,
        );
      }

      if (_isEditMode && _vanId != null) {
        await FirebaseFirestore.instance.collection('vans').doc(_vanId).update({
          'placa': _placaController.text.trim(),
          'marca': _marcaController.text.trim(),
          'modelo': _modeloController.text.trim(),
          'ano': int.parse(_anoController.text),
          'capacidade': int.parse(_capacidadeController.text),
          'cor': _corController.text.trim(),
          'vanFotoUrl': fotoUrl,
        });
      } else {
        final van = Van(
          id: '',
          placa: _placaController.text.trim(),
          marca: _marcaController.text.trim(),
          modelo: _modeloController.text.trim(),
          ano: int.parse(_anoController.text),
          capacidade: int.parse(_capacidadeController.text),
          cor: _corController.text.trim(),
          status: StatusVan.disponivel,
          motoristaId: motoristaId,
          vanFotoUrl: fotoUrl,
        );

        final vanDoc = await FirebaseFirestore.instance.collection('vans').add(van.toMap());

        await FirebaseFirestore.instance
            .collection('motoristas')
            .doc(motoristaId)
            .set({
              'vansIds': FieldValue.arrayUnion([vanDoc.id]),
            }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Van salva com sucesso!'),
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
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: NeonAppBar(
          title: _isEditMode ? 'Editar Van' : 'Cadastrar Nova Van',
          showMenuButton: false,
          showBackButton: true,
          onNotificationsPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TelaNotificacoes()),
            );
          },
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
                          label: Text(_isEditMode ? 'ATUALIZAR VAN' : 'SALVAR VAN'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

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
              if (_imageFile != null)
                FutureBuilder<Uint8List>(
                  future: _imageFile!.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      );
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                )
              else if (_fotoUrlExistente != null && _fotoUrlExistente!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _fotoUrlExistente!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => const Icon(Icons.airport_shuttle_outlined, size: 40),
                  ),
                )
              else
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
                    color: const Color.fromARGB(128, 0, 0, 0),
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
