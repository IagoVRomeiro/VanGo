import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/place_type.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../models/aluno.dart';
import '../models/motorista.dart';
import '../models/usuario.dart';
import '../models/van.dart';
import '../models/rota.dart';
import 'package:vango/screens/tela_notificacoes.dart';
import 'package:vango/widgets/neon_app_bar.dart';

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
  Timestamp? _criadoEm;

  final Map<String, bool> _diasSemana = {
    'Seg': false, 'Ter': false, 'Qua': false,
    'Qui': false, 'Sex': false, 'Sab': false, 'Dom': false,
  };

  List<Aluno> _motoristaAlunosDisponiveis = [];
  Map<String, Usuario> _usuariosAlunos = {};
  Set<String> _alunosSelecionadosParaRota = {};

  final TextEditingController _destinoController = TextEditingController();
  final FocusNode _destinoFocusNode = FocusNode();
  late final String _apiKey;
  GeoPoint? _localDestinoGeoPoint;

  @override
  void initState() {
    super.initState();
    _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (widget.rotaId != null) {
      _isEditMode = true;
    }
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _destinoController.dispose();
    _destinoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() {
      _carregandoDados = true;
    });

    final motoristaId = FirebaseAuth.instance.currentUser?.uid;
    if (motoristaId == null) {
      if (mounted) {
        setState(() {
          _carregandoDados = false;
        });
      }
      return;
    }

    try {
      await Future.wait([
        _carregarVans(motoristaId),
        _carregarAlunosMotorista(motoristaId),
      ]);

      if (_isEditMode) {
        await _carregarDadosDaRota(widget.rotaId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados iniciais: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _carregandoDados = false;
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
                .map((doc) => Aluno.fromMap(doc.id, doc.data()))
                .toList();
          }
          await _carregarUsuariosAlunos(alunosIds);
        } else {
          if (mounted) {
            setState(() {
              _usuariosAlunos = {};
            });
          }
        }
    }
  }

  Future<void> _carregarUsuariosAlunos(List<String> alunosIds) async {
    if (!mounted) return;
    if (alunosIds.isEmpty) {
      setState(() {
        _usuariosAlunos = {};
      });
      return;
    }

    const chunkSize = 10;
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (var i = 0; i < alunosIds.length; i += chunkSize) {
      final end = (i + chunkSize) > alunosIds.length ? alunosIds.length : i + chunkSize;
      futures.add(
        FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: alunosIds.sublist(i, end))
            .get(),
      );
    }

    final snapshots = await Future.wait(futures);
    final usuarios = <String, Usuario>{};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        usuarios[doc.id] = Usuario.fromSnapshot(doc);
      }
    }

    if (mounted) {
      setState(() {
        _usuariosAlunos = usuarios;
      });
    }
  }

  Future<void> _carregarDadosDaRota(String rotaId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rotas')
          .doc(rotaId)
          .get();

      if (doc.exists && mounted) {
        final rota = Rota.fromSnapshot(doc);

        _nomeController.text = rota.nome;
        _destinoController.text = rota.localDestinoNome;
        _localDestinoGeoPoint = rota.localDestino;
        _criadoEm = rota.criadoEm;

        _horarioInicio = _timeOfDayFromString(rota.horarioInicioPrevisto);
        _horarioFim = _timeOfDayFromString(rota.horarioFimPrevisto);

        try {
          _vanSelecionada = _vansDisponiveis.firstWhere(
            (van) => van.id == rota.vanId,
          );
        } catch (e) {
          _vanSelecionada = null;
        }

        setState(() {
          _diasSemana.forEach((key, value) {
            _diasSemana[key] = rota.diasSemana[key] ?? false;
          });
          _alunosSelecionadosParaRota = Set<String>.from(rota.listaAlunosIds);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar rota: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

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

    if (_destinoController.text.trim().isEmpty ||
        _localDestinoGeoPoint == null ||
        _vanSelecionada == null ||
        _horarioInicio == null ||
        _horarioFim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Por favor, selecione o destino e preencha os demais campos.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    final destino = _localDestinoGeoPoint!;

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
      final proximoHorario = _calcularProximoHorario(_horarioInicio!, _diasSemana);

      final rotaData = Rota(
        id: _isEditMode ? widget.rotaId! : '',
        nome: _nomeController.text.trim(),
        localDestino: destino,
        localDestinoNome: _destinoController.text.trim(),
        vanId: _vanSelecionada!.id,
        motoristaId: user.uid,
        listaAlunosIds: _alunosSelecionadosParaRota.toList(),
        diasSemana: _diasSemana,
        horarioInicioPrevisto: _horarioInicio!.to24HourString(),
        horarioFimPrevisto: _horarioFim!.to24HourString(),
        horaInicio: proximoHorario != null ? Timestamp.fromDate(proximoHorario) : null,
        status: StatusRota.planejada,
        criadoEm: _criadoEm,
      );

      final rotaCollection = FirebaseFirestore.instance.collection('rotas');

      if (_isEditMode) {
        await rotaCollection.doc(widget.rotaId!).update(rotaData.toUpdateMap());
      } else {
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

  DateTime? _calcularProximoHorario(TimeOfDay time, Map<String, bool> dias) {
    if (dias.values.every((d) => !d)) return null;

    final now = DateTime.now();
    final int todayWeekday = now.weekday; // 1 (Monday) to 7 (Sunday)

    // Map your string days to DateTime weekday constants
    const dayMapping = {
      'Seg': DateTime.monday,
      'Ter': DateTime.tuesday,
      'Qua': DateTime.wednesday,
      'Qui': DateTime.thursday,
      'Sex': DateTime.friday,
      'Sab': DateTime.saturday,
      'Dom': DateTime.sunday,
    };

    for (int i = 0; i < 7; i++) {
      int weekday = (todayWeekday + i - 1) % 7 + 1; // Check from today onwards
      String dayKey = dayMapping.entries.firstWhere((e) => e.value == weekday).key;

      if (dias[dayKey] == true) {
        DateTime nextDay = DateTime(now.year, now.month, now.day + i);
        DateTime nextOccurrence = DateTime(
          nextDay.year,
          nextDay.month,
          nextDay.day,
          time.hour,
          time.minute,
        );

        if (nextOccurrence.isAfter(now)) {
          return nextOccurrence;
        }
      }
    }

    // If no time this week is in the future, find the first available day next week
    for (int i = 0; i < 7; i++) {
      int weekday = (todayWeekday + i - 1) % 7 + 1;
      String dayKey = dayMapping.entries.firstWhere((e) => e.value == weekday).key;
      if (dias[dayKey] == true) {
        DateTime nextDay = DateTime(now.year, now.month, now.day + i + 7);
        return DateTime(
          nextDay.year,
          nextDay.month,
          nextDay.day,
          time.hour,
          time.minute,
        );
      }
    }

    return null;
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
                ?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: _diasSemana.keys.map((String key) {
            return FilterChip(
              label: Text(key),
              selected: _diasSemana[key]!,
              labelStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
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

  Widget _buildDestinoField(BuildContext context) {
    if (_apiKey.isEmpty || _apiKey == 'YOUR_API_KEY') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _destinoController,
            focusNode: _destinoFocusNode,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Local de Destino (Faculdade)',
              border: OutlineInputBorder(),
              hintText: 'Configure GOOGLE_MAPS_API_KEY no assets/.env',
            ),
            validator: (_) => 'Configure GOOGLE_MAPS_API_KEY para usar o autocomplete.',
          ),
          const SizedBox(height: 8),
          Text(
            'É necessário configurar a chave do Google Maps no arquivo assets/.env para habilitar o campo.',
            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
          ),
        ],
      );
    }

    return GooglePlaceAutoCompleteTextField(
      textEditingController: _destinoController,
      focusNode: _destinoFocusNode,
      googleAPIKey: _apiKey,
      debounceTime: 400,
      countries: const ['br'],
      language: 'pt-BR',
      placeType: PlaceType.establishment,
      isLatLngRequired: true,
      textStyle: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
      inputDecoration: const InputDecoration(
        labelText: 'Local de Destino (Faculdade)',
        border: OutlineInputBorder(),
      ),
      validator: (value, _) =>
          value == null || value.trim().isEmpty ? 'Informe o destino.' : null,
      itemClick: (Prediction prediction) {
        _destinoController.text = prediction.description ?? '';
        _destinoController.selection = TextSelection.fromPosition(
          TextPosition(offset: prediction.description?.length ?? 0),
        );
      },
      getPlaceDetailWithLatLng: (Prediction prediction) {
        if (prediction.lat != null && prediction.lng != null) {
          setState(() {
            _localDestinoGeoPoint = GeoPoint(
              double.parse(prediction.lat!),
              double.parse(prediction.lng!),
            );
          });
        }
      },
      itemBuilder: (context, index, Prediction prediction) {
        return ListTile(
          dense: true,
          title: Text(prediction.description ?? ''),
        );
      },
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
                ?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        _carregandoDados
            ? Center(
                child: Text(
                  "Carregando alunos...",
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                ),
              )
            : _motoristaAlunosDisponiveis.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Nenhum aluno vinculado ao seu perfil.\nGerencie seus alunos na tela 'Viagem'.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
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

                      final usuario = _usuariosAlunos[aluno.id];
                      final nome = usuario?.nome ?? 'Nome não informado';
                      final endereco = usuario?.endereco ?? 'Endereço não informado';

                      return CheckboxListTile(
                        title: Text(nome),
                        subtitle: Text(endereco),
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
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.red,
              onPrimary: Colors.white,
            ),
      ),
      child: Scaffold(
        appBar: NeonAppBar(
          title: _isEditMode ? 'Editar Rota' : 'Criar Nova Rota',
          showMenuButton: false,
          showBackButton: true,
          onNotificationsPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TelaNotificacoes()),
            );
          },
        ),
        body: _carregandoDados
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
                        TextFormField(
                            controller: _nomeController,
                            decoration: const InputDecoration(
                                labelText: 'Nome da Rota (ex: Manhã - PUC Coreu)',
                                border: OutlineInputBorder()),
                            validator: (v) =>
                                v!.isEmpty ? 'Campo obrigatório' : null),
                        const SizedBox(height: 16),
                        _buildDestinoField(context),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Van>(
                          isExpanded: true,
                          initialValue: _vanSelecionada,
                          items: _vansDisponiveis
                              .map((van) => DropdownMenuItem(
                                    value: van,
                                    child: Text(
                                        '${van.marca} ${van.modelo} - ${van.placa}', overflow: TextOverflow.ellipsis),                                  ))
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
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ))
                              : const Icon(Icons.save),
                          label: Text(
                              _isEditMode ? 'ATUALIZAR ROTA' : 'SALVAR ROTA'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
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
