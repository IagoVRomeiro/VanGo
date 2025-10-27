// lib/screens/tela_viagem.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Imports dos modelos
import '../models/aluno.dart';
import '../models/motorista.dart'; // 🔹 Import do Motorista
import '../models/van.dart';       // 🔹 Import da Van
import '../models/rota.dart';       // 🔹 Import da Rota

// Imports das telas de destino
import 'tela_criarRota.dart';
import 'tela_criarVan.dart';
import 'tela_gerenciar_alunos.dart';
import 'tela_cadastro.dart'; // 🔹 Import da TelaCadastro

class TelaViagem extends StatefulWidget {
  const TelaViagem({super.key});

  @override
  State<TelaViagem> createState() => _TelaViagemState();
}

class _TelaViagemState extends State<TelaViagem> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Helper para o título das seções
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

  // -----------------------------------------------------------------
  // SEÇÃO 1: GERENCIAMENTO DA VAN
  // -----------------------------------------------------------------
  // 🔹 ATUALIZADO: Recebe um objeto 'Van' (que pode ser nulo)
  Widget _buildGerenciamentoVan(Van? van) {
    if (van != null) {
      // Card da Van Cadastrada
      return ListTile(
        leading: Image.network(
          van.vanFotoUrl ?? // ⬅️ Corrigido
              'https://placehold.co/100x100/EFEFEF/AAAAAA?text=Van',
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.airport_shuttle_outlined, size: 40),
        ),
        title: Text('${van.marca} ${van.modelo}'), // ⬅️ Corrigido
        subtitle: Text(van.placa), // ⬅️ Corrigido
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CadastrarVanScreen()),
          );
        },
      );
    } else {
      // Card para Adicionar Van
      return ListTile(
        leading: const Icon(Icons.add_circle_outline,
            color: Color(0xFFE53935), size: 40),
        title: const Text('Cadastrar Van'),
        subtitle: const Text('Adicione os dados do seu veículo'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // 🔹 ESTA É A SUA "REGRA 3"
          if (_currentUser == null) {
            // Se por algum motivo o usuário não estiver logado,
            // (embora a TelaMotorista já deva bloquear isso),
            // nós o enviamos para o cadastro.
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaCadastro()),
            );
          } else {
            // Usuário logado, vai para a tela de cadastro da van
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CadastrarVanScreen()),
            );
          }
        },
      );
    }
  }

  // -----------------------------------------------------------------
  // SEÇÃO 2: GERENCIAMENTO DE ROTAS
  // -----------------------------------------------------------------
  // 🔹 ATUALIZADO: Busca da coleção raiz '/rotas'
  Widget _buildGerenciamentoRotas() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rotas') // ⬅️ Corrigido: Coleção Raiz
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
            // 🔹 ATUALIZADO: Usa o modelo Rota
            final rota = Rota.fromSnapshot(snapshot.data!.docs[index]
                as DocumentSnapshot<Map<String, dynamic>>);

            final diasAtivos = rota.diasSemana.entries
                .where((e) => e.value == true)
                .map((e) => e.key)
                .join(', ');
            final subtitulo =
                '${rota.localDestino}${diasAtivos.isNotEmpty ? " ($diasAtivos)" : ""}';

            return ListTile(
              leading: const Icon(Icons.route_outlined,
                  color: Color(0xFFE53935), size: 40),
              title: Text(rota.nome),
              subtitle: Text(subtitulo),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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

  // 🔹 ATUALIZADO: Recebe o objeto 'Van' para checagem
  Widget _buildCriarRotaTile(BuildContext context, Van? van) {
    return ListTile(
      leading: const Icon(Icons.add_circle_outline,
          color: Color(0xFFE53935), size: 40),
      title: const Text('Criar Nova Rota'),
      subtitle: const Text('Adicionar um novo trajeto'),
      onTap: () {
        // 🔹 ATUALIZADO: Verifica se a van (não 'motoristaData') existe
        if (van != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CriarRotaScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Você precisa cadastrar uma van antes de criar uma rota.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
    );
  }

  // -----------------------------------------------------------------
  // SEÇÃO 3: GERENCIAMENTO DE ALUNOS
  // -----------------------------------------------------------------
  // 🔹 ATUALIZADO: Recebe a 'listaDeIds' do motorista
  Widget _buildGerenciamentoAlunos(List<String> alunosIds) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.people_outline,
              color: Color(0xFFE53935), size: 40),
          title: const Text("Alunos Vinculados"),
          subtitle: const Text("Ver lista de passageiros e solicitações"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TelaGerenciarAlunos()),
            );
          },
        ),
        if (alunosIds.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Center(child: Text("Nenhum aluno vinculado.")),
          )
        else
          // (O seu StreamBuilder de Alunos aqui estava correto e foi mantido)
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
              // ... (ListView.builder de alunos)
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final aluno =
                      Aluno.fromMap(doc.id, doc.data() as Map<String, dynamic>);
                  final nome = aluno.nome;
                  final faculdade =
                      aluno.endereco;

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
              const Text(
                "Você precisa estar logado para ver esta página.",
                style: TextStyle(fontSize: 16),
              ),
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

    // O 'build' principal agora busca o Motorista
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('motoristas')
            .doc(_currentUser!.uid) 
            .snapshots(),
        builder: (context, motoristaSnapshot) {
          if (motoristaSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!motoristaSnapshot.hasData || !motoristaSnapshot.data!.exists) {
            return const Center(
                child: Text('Erro: Não foi possível carregar o perfil.'));
          }

          // 1. Temos o Motorista
          final motorista = Motorista.fromMap(motoristaSnapshot.data!.id,
              motoristaSnapshot.data!.data() as Map<String, dynamic>);
          final vanId = motorista.vanId;

          // 2. Agora, buscamos a Van (com um StreamBuilder aninhado)
          return StreamBuilder<DocumentSnapshot>(
            stream: vanId != null
                ? FirebaseFirestore.instance.collection('vans').doc(vanId).snapshots()
                : null, // Se vanId for nulo, o stream é nulo
            builder: (context, vanSnapshot) {
              
              Van? van; // A van pode ser nula
              if (vanSnapshot.connectionState == ConnectionState.active &&
                  vanSnapshot.hasData &&
                  vanSnapshot.data!.exists) {
                van = Van.fromSnapshot(
                    vanSnapshot.data! as DocumentSnapshot<Map<String, dynamic>>);
              }
              
              // Se o 'vanId' existir mas a van ainda estiver carregando
              if (vanId != null && vanSnapshot.connectionState == ConnectionState.waiting) {
                 return const Center(child: CircularProgressIndicator());
              }

              // 3. Finalmente, construímos a tela
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SEÇÃO 1: Gerenciamento da Van (passa o objeto 'van' ou null)
                  _buildSectionTitle(context, 'Gerenciamento do Veículo'),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: _buildGerenciamentoVan(van),
                  ),

                  // SEÇÃO 2: Gerenciamento de Rotas
                  _buildSectionTitle(context, 'Gerenciamento da Rota'),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildGerenciamentoRotas(),
                        const Divider(height: 1),
                        _buildCriarRotaTile(context, van), // Passa o 'van'
                      ],
                    ),
                  ),

                  // SEÇÃO 3: Gerenciamento de Alunos
                  _buildSectionTitle(context, 'Alunos'),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: _buildGerenciamentoAlunos(motorista.alunosIds ?? []),
                  ),

                  const SizedBox(height: 80), // Espaço para o footer
                ],
              );
            },
          );
        },
      ),
    );
  }
}