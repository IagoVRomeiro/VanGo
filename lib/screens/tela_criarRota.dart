// lib/screens/tela_criarRota.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vango/models/rota.dart';
import 'package:vango/models/van.dart';

class CriarRotaScreen extends StatefulWidget {
  const CriarRotaScreen({super.key});

  @override
  State<CriarRotaScreen> createState() => _CriarRotaScreenState();
}

class _CriarRotaScreenState extends State<CriarRotaScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _distanciaController = TextEditingController();

  Van? _vanSelecionada;
  DateTime? _horarioInicio;
  DateTime? _horarioFim;
  bool _isLoading = false;

  List<Van> _vansDisponiveis = [];
  bool _carregandoVans = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _distanciaController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosIniciais() async {
    final motoristaId = FirebaseAuth.instance.currentUser?.uid;
    if (motoristaId == null) {
      if (mounted) setState(() => _carregandoVans = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vans')
          .where('motoristaId', isEqualTo: motoristaId)
          .where('status', isEqualTo: StatusVan.disponivel.name)
          .get();

      if (mounted) {
        setState(() {
          _vansDisponiveis =
              snapshot.docs.map((doc) => Van.fromSnapshot(doc)).toList();
          _carregandoVans = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao carregar vans: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
        setState(() => _carregandoVans = false);
      }
    }
  }

  Future<void> _salvarRota() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_vanSelecionada == null ||
        _horarioInicio == null ||
        _horarioFim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, preencha todos os campos.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    
    // NOVO: Validação para garantir que o horário de fim seja posterior ao de início
    if (_horarioInicio!.isAfter(_horarioFim!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('O horário de fim deve ser depois do horário de início.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro: Usuário não está logado.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final novaRota = Rota(
        id: '', 
        nome: _nomeController.text.trim(),
        // NOVO: Usando o ID do documento da van em vez da placa
        vanId: _vanSelecionada!.id, 
        motoristaId: user.uid,
        listaAlunosIds: [], 
        horarioInicioPrevisto: Timestamp.fromDate(_horarioInicio!),
        horarioFimPrevisto: Timestamp.fromDate(_horarioFim!),
        distanciaTotal: double.tryParse(_distanciaController.text) ?? 0.0,
        status: StatusRota.planejada, 
      );

      await FirebaseFirestore.instance.collection('rotas').add(novaRota.toMap());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Rota criada com sucesso!'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao criar rota: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<DateTime?> _selecionarDataHora(DateTime initialDate) async {
    final data = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (data == null) return null;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (hora == null) return null;

    return DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Nova Rota'),
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
                    TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                            labelText: 'Nome da Rota (ex: Manhã - PUC Coreu)',
                            border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                    const SizedBox(height: 16),
                    _carregandoVans
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<Van>(
                            value: _vanSelecionada,
                            items: _vansDisponiveis
                                .map((van) => DropdownMenuItem(
                                      value: van,
                                      child: Text(
                                          '${van.marca} ${van.modelo} - ${van.placa}'),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _vanSelecionada = value),
                            decoration: InputDecoration(
                              labelText: 'Selecionar Van',
                              border: const OutlineInputBorder(),
                              errorText: _vansDisponiveis.isEmpty
                                  ? 'Nenhuma van disponível cadastrada.'
                                  : null,
                            ),
                            validator: (value) =>
                                value == null ? 'Selecione uma van.' : null,
                          ),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _distanciaController,
                        decoration: const InputDecoration(
                            labelText: 'Distância Total Estimada (km)',
                            border: OutlineInputBorder()),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Horário de Início Previsto'),
                      subtitle: Text(_horarioInicio == null
                          ? 'Toque para definir'
                          : DateFormat('dd/MM/yyyy HH:mm')
                              .format(_horarioInicio!)),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final data = await _selecionarDataHora(
                            _horarioInicio ?? DateTime.now());
                        if (data != null) {
                          setState(() => _horarioInicio = data);
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Horário de Fim Previsto'),
                      subtitle: Text(_horarioFim == null
                          ? 'Toque para definir'
                          : DateFormat('dd/MM/yyyy HH:mm').format(_horarioFim!)),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final data = await _selecionarDataHora(
                            _horarioFim ?? _horarioInicio ?? DateTime.now());
                        if (data != null) setState(() => _horarioFim = data);
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _salvarRota,
                      icon: const Icon(Icons.save),
                      label: const Text('SALVAR ROTA'),
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
}