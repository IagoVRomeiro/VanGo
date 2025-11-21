import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/aluno.dart';
import '../models/motorista.dart';
import '../models/van.dart';
import '../models/rota.dart'; // ⬅️ IMPORTA O NOVO MODELO

class CriarRotaScreen extends StatefulWidget {
  final String? rotaId;
  const CriarRotaScreen({super.key, this.rotaId});

  @override
  State<CriarRotaScreen> createState() => _CriarRotaScreenState();
}

class _CriarRotaScreenState extends State<CriarRotaScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();

  Van? _vanSelecionada;
  TimeOfDay? _horarioInicio;
  TimeOfDay? _horarioFim;
  bool _isLoading = false;
  List<Van> _vansDisponiveis = [];
  bool _carregandoDados = true;
  bool _isEditMode = false;
  Timestamp? _criadoEm; // Para preservar data de criação

  final Map<String, bool> _diasSemana = {
    'Seg': false, 'Ter': false, 'Qua': false,
    'Qui': false, 'Sex': false, 'Sab': false, 'Dom': false,
  };

  List<Aluno> _motoristaAlunosDisponiveis = [];
  Set<String> _alunosSelecionadosParaRota = {};

  List<String> _listaFaculdades = [];
  String? _faculdadeSelecionada;
  bool _carregandoFaculdades = true;

  @override
  void initState() {
    super.initState();
    if (widget.rotaId != null) {
      _isEditMode = true;
    }
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() {
      _carregandoDados = true;
      _carregandoFaculdades = true;
    });

    final motoristaId = FirebaseAuth.instance.currentUser?.uid;
    if (motoristaId == null) {
      if (mounted) {
        setState(() {
          _carregandoDados = false;
          _carregandoFaculdades = false;
        });
      }
      return;
    }

    try {
      await Future.wait([
        _carregarVans(motoristaId),
        _carregarAlunosMotorista(motoristaId),
        _carregarFaculdades(),
      ]);

      if (_isEditMode) {
        // 🔹 Carrega os dados da rota usando o ID
        await _carregarDadosDaRota(widget.rotaId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao carregar dados iniciais: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _carregandoDados = false;
          _carregandoFaculdades = false;
        });
      }
    }
  }

  Future<void> _carregarVans(String motoristaId) async {
    final vansSnapshot = await FirebaseFirestore.instance
        .collection('vans')
        .where('motoristaId', isEqualTo: motoristaId)
        .where('status', isEqualTo: StatusVan.disponivel.name)
        .get();
    if (mounted) {
      _vansDisponiveis =
          vansSnapshot.docs.map((doc) => Van.fromSnapshot(doc)).toList();
    }
  }

  Future<void> _carregarAlunosMotorista(String motoristaId) async {
    final motoristaDoc = await FirebaseFirestore.instance
        .collection('motoristas')
        .doc(motoristaId)
        .get();
    if (motoristaDoc.exists && mounted) {
      final motorista =
          Motorista.fromMap(motoristaDoc.id, motoristaDoc.data()!);
      final List<String> alunosIds = motorista.alunosIds ?? [];
      if (alunosIds.isNotEmpty) {
        final alunosSnapshot = await FirebaseFirestore.instance
            .collection('alunos')
            .where(FieldPath.documentId, whereIn: alunosIds)
            .get();
        if (mounted) {
          _motoristaAlunosDisponiveis = alunosSnapshot.docs
              .map((doc) => Aluno.fromMap(doc.id, doc.data()!))
              .toList();
        }
      }
    }
  }

  Future<void> _carregarFaculdades() async {
    // Simulação de API
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _listaFaculdades = [
          'PUC Minas - Coração Eucarístico',
          'PUC Minas - Praça da Liberdade',
          'UFMG - Campus Pampulha',
          'UNA - Aimorés',
          'Newton Paiva - Unidade Silva Lobo',
          'Centro Universitário de Belo Horizonte - UniBH',
        ];
        _listaFaculdades.sort();
        _carregandoFaculdades = false;
      });
    }
  }

  /// 🔹 ATUALIZADO: Carrega da coleção raiz '/rotas' e usa o modelo Rota
  Future<void> _carregarDadosDaRota(String rotaId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rotas') // Coleção Raiz
          .doc(rotaId)
          .get();

      if (doc.exists && mounted) {
        // Usa o factory do modelo
        final rota = Rota.fromSnapshot(doc);

        _nomeController.text = rota.nome;
        _faculdadeSelecionada = rota.localDestino; // ⬅️ CORRIGIDO
        _criadoEm = rota.criadoEm;

        if (_faculdadeSelecionada != null &&
            !_listaFaculdades.contains(_faculdadeSelecionada)) {
          _faculdadeSelecionada = null;
        }

        _horarioInicio = _timeOfDayFromString(rota.horarioInicioPrevisto); // ⬅️ CORRIGIDO
        _horarioFim = _timeOfDayFromString(rota.horarioFimPrevisto); // ⬅️ CORRIGIDO

        try {
          _vanSelecionada = _vansDisponiveis.firstWhere(
            (van) => van.id == rota.vanId,
          );
        } catch (e) {
          _vanSelecionada = null;
        }

        setState(() {
          _diasSemana.forEach((key, value) {
            _diasSemana[key] = rota.diasSemana[key] ?? false; // ⬅️ CORRIGIDO
          });
          _alunosSelecionadosParaRota = Set<String>.from(rota.listaAlunosIds);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao carregar rota: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 🔹 ATUALIZADO: Salva usando o Modelo Rota na coleção raiz
  Future<void> _salvarRota() async {
    if (!_formKey.currentState!.validate()) return;

    final bool diaSelecionado = _diasSemana.values.any((dia) => dia == true);
    if (!diaSelecionado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecione pelo menos um dia da semana.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (_faculdadeSelecionada == null ||
        _vanSelecionada == null ||
        _horarioInicio == null ||
        _horarioFim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, preencha todos os campos.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final inicioEmMinutos = _horarioInicio!.hour * 60 + _horarioInicio!.minute;
    final fimEmMinutos = _horarioFim!.hour * 60 + _horarioFim!.minute;

    if (inicioEmMinutos >= fimEmMinutos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('O horário de chegada deve ser depois do horário de início.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // 🔹 CORREÇÃO: Cria o objeto Rota
      final rotaData = Rota(
        id: _isEditMode ? widget.rotaId! : '',
        nome: _nomeController.text.trim(),
        localDestino: _faculdadeSelecionada!, // ⬅️ CORRIGIDO
        vanId: _vanSelecionada!.id,
        motoristaId: user.uid,
        listaAlunosIds: _alunosSelecionadosParaRota.toList(),
        diasSemana: _diasSemana, // ⬅️ CORRIGIDO
        horarioInicioPrevisto: _horarioInicio!.to24HourString(),
        horarioFimPrevisto: _horarioFim!.to24HourString(),
        status: StatusRota.planejada,
        criadoEm: _criadoEm, // Preserva o 'criadoEm' original
      );

      final rotaCollection = FirebaseFirestore.instance.collection('rotas');

      if (_isEditMode) {
        // Usa o toUpdateMap() para não sobrescrever o 'criadoEm'
        await rotaCollection.doc(widget.rotaId!).update(rotaData.toUpdateMap());
      } else {
        // Usa o toMap() normal que inclui o serverTimestamp
        await rotaCollection.add(rotaData.toMap());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Rota ${_isEditMode ? 'atualizada' : 'criada'} com sucesso!'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao salvar rota: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<TimeOfDay?> _selecionarHora(TimeOfDay? initialTime) async {
    final hora = await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
    );
    return hora;
  }

  Widget _buildDiasSemanaChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
          child: Text(
            "Dias da Semana",
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.black54, fontWeight: FontWeight.bold),
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: _diasSemana.keys.map((String key) {
            return FilterChip(
              label: Text(key),
              selected: _diasSemana[key]!,
              onSelected: (bool selected) {
                setState(() {
                  _diasSemana[key] = selected;
                });
              },
              selectedColor: Colors.red.shade100,
              checkmarkColor: Colors.red,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSeletorAlunos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 4.0),
          child: Text(
            "Alunos na Rota",
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.black54, fontWeight: FontWeight.bold),
          ),
        ),
        _carregandoDados
            ? const Center(child: Text("Carregando alunos..."))
            : _motoristaAlunosDisponiveis.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Nenhum aluno vinculado ao seu perfil.\nGerencie seus alunos na tela 'Viagem'.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _motoristaAlunosDisponiveis.length,
                    itemBuilder: (context, index) {
                      final aluno = _motoristaAlunosDisponiveis[index];
                      final bool isSelected =
                          _alunosSelecionadosParaRota.contains(aluno.id);

                      return CheckboxListTile(
                        title: Text(aluno.nome),
                        subtitle: Text(aluno.endereco), // 🔹 CORRIGIDO
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _alunosSelecionadosParaRota.add(aluno.id);
                            } else {
                              _alunosSelecionadosParaRota.remove(aluno.id);
                            }
                          });
                        },
                      );
                    },
                  ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Rota' : 'Criar Nova Rota'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _carregandoDados
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
                        validator: (v) =>
                            v!.isEmpty ? 'Campo obrigatório' : null),
                    const SizedBox(height: 16),
                    _carregandoFaculdades
                        ? const Center(child: Text('Carregando faculdades...'))
                        : DropdownButtonFormField<String>(
                            isExpanded: true, // ⬅️ FIX OVERFLOW
                            value: _faculdadeSelecionada,
                            items: _listaFaculdades
                                .map((faculdade) => DropdownMenuItem(
                                      value: faculdade,
                                      child: Flexible(child: Text(faculdade)),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _faculdadeSelecionada = value),
                            decoration: InputDecoration(
                              labelText: 'Local de Destino (Faculdade)',
                              border: const OutlineInputBorder(),
                              errorText: _listaFaculdades.isEmpty &&
                                      !_carregandoFaculdades
                                  ? 'Nenhuma faculdade encontrada.'
                                  : null,
                            ),
                            validator: (value) => value == null
                                ? 'Selecione uma faculdade.'
                                : null,
                          ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Van>(
                      isExpanded: true, // ⬅️ FIX OVERFLOW
                      value: _vanSelecionada,
                      items: _vansDisponiveis
                          .map((van) => DropdownMenuItem(
                                value: van,
                                child: Flexible(
                                  child: Text(
                                      '${van.marca} ${van.modelo} - ${van.placa}'),
                                ),
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
                    _buildDiasSemanaChips(),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Horário de Início'),
                      subtitle: Text(_horarioInicio == null
                          ? 'Toque para definir'
                          : _horarioInicio!.format(context)),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final hora = await _selecionarHora(_horarioInicio);
                        if (hora != null) {
                          setState(() => _horarioInicio = hora);
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Horário de Chegada (Previsto)'),
                      subtitle: Text(_horarioFim == null
                          ? 'Toque para definir'
                          : _horarioFim!.format(context)),
                      trailing: const Icon(Icons.schedule),
                      onTap: () async {
                        final hora = await _selecionarHora(_horarioFim);
                        if (hora != null) setState(() => _horarioFim = hora);
                      },
                    ),
                    const Divider(height: 24),
                    _buildSeletorAlunos(),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _salvarRota,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ))
                          : const Icon(Icons.save),
                      label: Text(
                          _isEditMode ? 'ATUALIZAR ROTA' : 'SALVAR ROTA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
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

// Helpers de TimeOfDay
extension TimeOfDayExtension on TimeOfDay {
  String to24HourString() {
    final String hourString = hour.toString().padLeft(2, '0');
    final String minuteString = minute.toString().padLeft(2, '0');
    return '$hourString:$minuteString';
  }
}

TimeOfDay? _timeOfDayFromString(String? timeString) {
  if (timeString == null) return null;
  try {
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  } catch (e) {
    return null;
  }
}