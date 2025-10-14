// lib/screens/tela_criarVan.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vango/models/van.dart';

class CadastrarVanScreen extends StatefulWidget {
  const CadastrarVanScreen({super.key});

  @override
  State<CadastrarVanScreen> createState() => _CadastrarVanScreenState();
}

class _CadastrarVanScreenState extends State<CadastrarVanScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para os campos de texto
  final _placaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _marcaController = TextEditingController();
  final _anoController = TextEditingController();
  final _capacidadeController = TextEditingController();
  final _corController = TextEditingController();
  final _fotoUrlController = TextEditingController();

  // Variáveis de estado para outros tipos de input
  bool _docValida = true;
  String? _statusSelecionado = 'disponível';
  bool _isLoading = false;

  final List<String> _statusOptions = ['disponível', 'em manutenção', 'em rota'];

  @override
  void dispose() {
    // É muito importante limpar os controladores para evitar vazamentos de memória
    _placaController.dispose();
    _modeloController.dispose();
    _marcaController.dispose();
    _anoController.dispose();
    _capacidadeController.dispose();
    _corController.dispose();
    _fotoUrlController.dispose();
    super.dispose();
  }

  Future<void> _salvarVan() async {
    // 1. Valida todos os campos do formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. Pega o ID do motorista logado
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
    });

    // 3. Cria um objeto Van com os dados do formulário
    final van = Van(
      placa: _placaController.text.trim().toUpperCase(),
      modelo: _modeloController.text.trim(),
      marca: _marcaController.text.trim(),
      ano: int.parse(_anoController.text),
      capacidade: int.parse(_capacidadeController.text),
      cor: _corController.text.trim(),
      documentacaoValida: _docValida,
      status: _statusSelecionado!,
      motoristaId: motoristaId,
      fotoUrl: _fotoUrlController.text.trim().isEmpty
          ? null
          : _fotoUrlController.text.trim(),
    );

    // 4. Salva o objeto no Firestore
    try {
      // Usamos a placa como ID único do documento para evitar duplicatas
      await FirebaseFirestore.instance
          .collection('vans')
          .doc(van.placa)
          .set(van.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Van cadastrada com sucesso!'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(); // Volta para a tela anterior
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
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Nova Van'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(_placaController, 'Placa (ex: ABC1D23)'),
                    _buildTextField(_marcaController, 'Marca (ex: Mercedes-Benz)'),
                    _buildTextField(_modeloController, 'Modelo (ex: Sprinter)'),
                    _buildTextField(_corController, 'Cor'),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTextField(_anoController, 'Ano',
                                keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _buildTextField(_capacidadeController, 'Capacidade',
                                keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _statusSelecionado,
                      items: _statusOptions
                          .map((label) => DropdownMenuItem(
                                value: label,
                                child: Text(label),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _statusSelecionado = value),
                      decoration: const InputDecoration(
                          labelText: 'Status', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Documentação Válida'),
                      value: _docValida,
                      onChanged: (value) => setState(() => _docValida = value),
                      contentPadding: EdgeInsets.zero,
                    ),
                    _buildTextField(_fotoUrlController, 'URL da Foto (Opcional)',
                        isRequired: false),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _salvarVan,
                      icon: const Icon(Icons.save),
                      label: const Text('SALVAR VAN'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget auxiliar para evitar repetição de código nos campos de texto
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
              int.tryParse(value!) == null) {
            return 'Por favor, insira um número válido.';
          }
          return null;
        },
      ),
    );
  }
}