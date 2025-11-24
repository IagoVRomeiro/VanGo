// lib/screens/tela_viagem.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Imports dos modelos
import '../models/aluno.dart';
import '../models/motorista.dart';
import '../models/van.dart';
import '../models/rota.dart';
import 'tela_motorista.dart';

// Imports das telas de destino
import 'tela_criar_rota.dart';
import 'tela_criar_van.dart';
import 'tela_gerenciar_alunos.dart';
import 'tela_cadastro.dart';

class TelaViagem extends StatefulWidget {
  const TelaViagem({super.key});

  @override
  State<TelaViagem> createState() => _TelaViagemState();
}

class _TelaViagemState extends State<TelaViagem> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

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

  Widget _buildGerenciamentoVan(Van? van) {
    if (van != null) {
      return ListTile(
        leading: Image.network(
          van.vanFotoUrl ?? 'https://placehold.co/100x100/EFEFEF/AAAAAA?text=Van',
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
            MaterialPageRoute(builder: (_) => const CadastrarVanScreen()),
          );
        },
      );
    } else {
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
            if (rota.status == StatusRota.planejada) {
              trailingWidget = ElevatedButton(
                onPressed: () => _iniciarRota(rota.id),
                child: const Text('Iniciar'),
              );
            } else if (rota.status == StatusRota.emAndamento) {
              trailingWidget = ElevatedButton(
                onPressed: () => _pararRota(rota.id),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Parar'),
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
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TelaMotorista(rotaParaExibirId: rotaId),
          ),
        );
      }
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

  Future<void> _pararRota(String rotaId) async {
    try {
      await FirebaseFirestore.instance.collection('rotas').doc(rotaId).update({
        'status': StatusRota.concluida.name,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rota concluída.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao parar a rota: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

    Widget _buildCriarRotaTile(BuildContext context, Van? van) {

      return ListTile(

        leading: Icon(Icons.add_circle_outline,

            color: Theme.of(context).colorScheme.primary, size: 40),
      title: const Text('Criar Nova Rota'),
      subtitle: const Text('Adicionar um novo trajeto'),
      onTap: () {
        if (van != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CriarRotaScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você precisa cadastrar uma van antes de criar uma rota.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
    );
  }

  Widget _buildGerenciamentoAlunos(List<String> alunosIds) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.people_outline, color: Color(0xFFE53935), size: 40),
          title: const Text("Alunos Vinculados"),
          subtitle: const Text("Ver lista de passageiros e solicitações"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaGerenciarAlunos(showAppBar: true)),
            );
          },
        ),
        if (alunosIds.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Center(child: Text("Nenhum aluno vinculado.")),
          )
        else
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('alunos')
                .where(FieldPath.documentId, whereIn: alunosIds)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Carregando passageiros..."),
                ));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Center(child: Text("Nenhum passageiro encontrado.")),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final aluno = Aluno.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                  final nome = aluno.nome;
                  final faculdade = aluno.endereco;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: Text(nome.isNotEmpty ? nome[0] : 'A'),
                    ),
                    title: Text(nome),
                    subtitle: Text(faculdade),
                  );
                },
              );
            },
          ),
      ],
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('motoristas').doc(_currentUser!.uid).snapshots(),
        builder: (context, motoristaSnapshot) {
          if (motoristaSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!motoristaSnapshot.hasData || !motoristaSnapshot.data!.exists) {
            return const Center(child: Text('Erro: Não foi possível carregar o perfil.'));
          }

          final motorista = Motorista.fromMap(motoristaSnapshot.data!.id, motoristaSnapshot.data!.data() as Map<String, dynamic>);
          final vanId = motorista.vanId;

          return StreamBuilder<DocumentSnapshot>(
            stream: vanId != null ? FirebaseFirestore.instance.collection('vans').doc(vanId).snapshots() : null,
            builder: (context, vanSnapshot) {
              Van? van;
              if (vanSnapshot.connectionState == ConnectionState.active && vanSnapshot.hasData && vanSnapshot.data!.exists) {
                van = Van.fromSnapshot(vanSnapshot.data! as DocumentSnapshot<Map<String, dynamic>>);
              }
              
              if (vanId != null && vanSnapshot.connectionState == ConnectionState.waiting) {
                 return const Center(child: CircularProgressIndicator());
              }

              return _DriverDashboard(motorista: motorista, van: van);
            },
          );
        },
      ),
    );
  }
}

class _DriverDashboard extends StatelessWidget {
  final Motorista motorista;
  final Van? van;

  const _DriverDashboard({required this.motorista, this.van});

  @override
  Widget build(BuildContext context) {
    // Re-use the existing build methods from the state class
    final state = context.findAncestorStateOfType<_TelaViagemState>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        state._buildSectionTitle(context, 'Gerenciamento do Veículo'),
        Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: state._buildGerenciamentoVan(van),
        ),
        state._buildSectionTitle(context, 'Gerenciamento da Rota'),
        Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              state._buildGerenciamentoRotas(),
              const Divider(height: 1),
              state._buildCriarRotaTile(context, van),
            ],
          ),
        ),
        state._buildSectionTitle(context, 'Alunos'),
        Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: state._buildGerenciamentoAlunos(motorista.alunosIds ?? []),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
