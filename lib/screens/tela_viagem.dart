import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/motorista.dart';
import '../models/van.dart';
import '../models/rota.dart';
import 'tela_motorista.dart';
import 'tela_criar_rota.dart';
import 'tela_criar_van.dart';
import 'tela_cadastro.dart';

class TelaViagem extends StatefulWidget {
  const TelaViagem({super.key});

  @override
  State<TelaViagem> createState() => _TelaViagemState();
}

class _TelaViagemState extends State<TelaViagem> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Motorista? _motoristaAtual;
  List<Van> _vans = [];
  bool _carregandoMotorista = true;
  bool _carregandoVans = true;
  String? _erroMotorista;
  String? _erroVans;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _motoristaSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _vansSubscription;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _ouvirMotorista(_currentUser!.uid);
      _ouvirVans(_currentUser!.uid);
    }
  }

  @override
  void dispose() {
    _motoristaSubscription?.cancel();
    _vansSubscription?.cancel();
    super.dispose();
  }

  void _ouvirMotorista(String motoristaId) {
    _motoristaSubscription = FirebaseFirestore.instance
        .collection('motoristas')
        .doc(motoristaId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        if (!snapshot.exists) {
          setState(() {
            _motoristaAtual = null;
            _erroMotorista = 'Não foi possível encontrar o perfil do motorista.';
            _carregandoMotorista = false;
          });
          return;
        }
        setState(() {
          _motoristaAtual =
              Motorista.fromMap(snapshot.id, snapshot.data() ?? {});
          _erroMotorista = null;
          _carregandoMotorista = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _erroMotorista = 'Erro ao carregar motorista: $error';
          _carregandoMotorista = false;
        });
      },
    );
  }

  void _ouvirVans(String motoristaId) {
    _vansSubscription = FirebaseFirestore.instance
        .collection('vans')
        .where('motoristaId', isEqualTo: motoristaId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _vans = snapshot.docs.map((doc) => Van.fromSnapshot(doc)).toList();
          _erroVans = null;
          _carregandoVans = false;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _erroVans = 'Erro ao carregar vans: $error';
          _carregandoVans = false;
        });
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, left: 4.0, bottom: 4.0),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildGerenciamentoVan(List<Van> vans) {
    if (vans.isEmpty) {
      return ListTile(
        leading: Icon(Icons.add_circle_outline,
            color: Theme.of(context).colorScheme.primary, size: 40),
        title: const Text('Cadastrar Van'),
        subtitle: const Text('Adicione os dados do seu veículo'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          if (_currentUser == null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaCadastro()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CadastrarVanScreen()),
            );
          }
        },
      );
    }

    return Column(
      children: [
        ...vans.map(
          (van) => ListTile(
            leading: Image.network(
              van.vanFotoUrl ??
                  'https://placehold.co/100x100/EFEFEF/AAAAAA?text=Van',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.airport_shuttle_outlined, size: 40),
            ),
            title: Text('${van.marca} ${van.modelo}'),
            subtitle: Text(van.placa),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CadastrarVanScreen(van: van)),
              );
            },
          ),
        ),
        ListTile(
          leading: Icon(Icons.add_circle_outline,
              color: Theme.of(context).colorScheme.primary, size: 40),
          title: const Text('Cadastrar nova van'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CadastrarVanScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGerenciamentoRotas() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rotas')
          .where('motoristaId', isEqualTo: _currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(child: Text('Nenhuma rota cadastrada.')),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final rota = Rota.fromSnapshot(snapshot.data!.docs[index] as DocumentSnapshot<Map<String, dynamic>>);
            final diasAtivos = rota.diasSemana.entries
                .where((e) => e.value == true)
                .map((e) => e.key)
                .join(', ');
            final subtitulo = '${rota.localDestinoNome}${diasAtivos.isNotEmpty ? " ($diasAtivos)" : ""}';

            Widget? trailingWidget;
            if (rota.status == StatusRota.planejada ||
                rota.status == StatusRota.concluida) {
              trailingWidget = ElevatedButton(
                onPressed: () => _iniciarRota(rota.id),
                child: const Text('Iniciar'),
              );
            } else if (rota.status == StatusRota.emAndamento) {
              trailingWidget = ElevatedButton(
                onPressed: () => _abrirMapaDaRota(rota.id),
                child: const Text('Andamento'),
              );
            }
            
            return ListTile(
              leading: Icon(Icons.route_outlined,
                  color: Theme.of(context).colorScheme.primary, size: 40),
              title: Text(rota.nome),
              subtitle: Text(subtitulo),
              trailing: trailingWidget,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CriarRotaScreen(rotaId: rota.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _iniciarRota(String rotaId) async {
    try {
      await FirebaseFirestore.instance.collection('rotas').doc(rotaId).update({
        'status': StatusRota.emAndamento.name,
      });
      _abrirMapaDaRota(rotaId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao iniciar a rota: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _abrirMapaDaRota(String rotaId) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaMotorista(rotaParaExibirId: rotaId),
      ),
    );
  }

  Widget _buildCriarRotaTile(BuildContext context, bool possuiVan) {
    return ListTile(
      leading: Icon(
        Icons.add_circle_outline,
        color: Theme.of(context).colorScheme.primary,
        size: 40,
      ),
      title: const Text('Criar Nova Rota'),
      subtitle: const Text('Adicionar um novo trajeto'),
      onTap: () {
        if (possuiVan) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CriarRotaScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Você precisa cadastrar pelo menos uma van antes de criar uma rota.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Você precisa estar logado para ver esta página.", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton(
                child: const Text("Ir para Cadastro/Login"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TelaCadastro()),
                  );
                },
              )
            ],
          ),
        ),
      );
    }

    final motorista = _motoristaAtual;
    final bool carregando = _carregandoMotorista || _carregandoVans;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (carregando)
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: LinearProgressIndicator(),
            ),
          if (_erroMotorista != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                _erroMotorista!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_erroVans != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                _erroVans!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (!_carregandoMotorista && motorista == null && _erroMotorista == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Text('Perfil de motorista não encontrado.'),
              ),
            ),
          if (motorista != null) _buildDriverDashboard(motorista, _vans),
        ],
      ),
    );
  }

  Widget _buildDriverDashboard(Motorista motorista, List<Van> vans) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(context, 'Gerenciamento do Veículo'),
        Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: _buildGerenciamentoVan(vans),
        ),
        _buildSectionTitle(context, 'Gerenciamento da Rota'),
        Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGerenciamentoRotas(),
              const Divider(height: 1),
              _buildCriarRotaTile(context, vans.isNotEmpty),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
