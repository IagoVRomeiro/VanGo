import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Imports das telas de destino
import 'tela_criarRota.dart';
import 'tela_criarVan.dart';
// 🔹 ADICIONADO: Import do modelo Aluno
import '../models/aluno.dart'; // Presumindo que este arquivo exista
// 🔹 ADICIONADO: Import da nova tela de gerenciamento
import 'tela_gerenciar_alunos.dart';

class TelaViagem extends StatefulWidget {
  const TelaViagem({super.key});

  @override
  State<TelaViagem> createState() => _TelaViagemState();
}

class _TelaViagemState extends State<TelaViagem> {
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

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
  Widget _buildGerenciamentoVan(Map<String, dynamic> motoristaData) {
    final veiculo = motoristaData['veiculo'];
    final vanCadastrada =
        veiculo != null && veiculo is String && veiculo.isNotEmpty;

    if (vanCadastrada) {
      // Card da Van Cadastrada
      return ListTile(
        leading: Image.network(
          motoristaData['vanFotoUrl'] ??
              'https://placehold.co/100x100/EFEFEF/AAAAAA?text=Van',
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.airport_shuttle_outlined, size: 40),
        ),
        title: Text(motoristaData['veiculo'] ?? 'Veículo não cadastrado'),
        subtitle: Text(motoristaData['placa'] ?? 'Placa não informada'),
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
        // 🔹 ATUALIZADO: Tamanho do ícone padronizado
        leading: const Icon(Icons.add_circle_outline,
            color: Color(0xFFE53935), size: 40),
        title: const Text('Cadastrar Van'),
        subtitle: const Text('Adicione os dados do seu veículo'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CadastrarVanScreen()),
          );
        },
      );
    }
  }

  // -----------------------------------------------------------------
  // SEÇÃO 2: GERENCIAMENTO DE ROTAS
  // -----------------------------------------------------------------
  Widget _buildGerenciamentoRotas(Map<String, dynamic> motoristaData) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('motoristas')
          .doc(_uid)
          .collection('rotas')
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
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final nome = data['nome'] ?? 'Rota sem nome';
            // 🔹 ATUALIZADO: Mostra o local de destino
            final localDestino =
                data['localDestino'] ?? 'Destino não informado';

            // 🔹 ATUALIZADO: Lógica para mostrar dias da semana
            final diasData =
                (data['diasSemana'] as Map?)?.cast<String, bool>() ?? {};
            final diasAtivos = diasData.entries
                .where((e) => e.value == true)
                .map((e) => e.key)
                .join(', ');
            final subtitulo =
                '$localDestino${diasAtivos.isNotEmpty ? " ($diasAtivos)" : ""}';

            return ListTile(
              leading: const Icon(Icons.route_outlined,
                  color: Color(0xFFE53935), size: 40),
              title: Text(nome),
              subtitle: Text(subtitulo),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    // Envia o ID da rota para a tela de edição
                    builder: (_) => CriarRotaScreen(rotaId: doc.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 🔹 ATUALIZADO: Aceita 'motoristaData' para checagem
  Widget _buildCriarRotaTile(
      BuildContext context, Map<String, dynamic> motoristaData) {
    return ListTile(
      // 🔹 ATUALIZADO: Tamanho do ícone padronizado
      leading: const Icon(Icons.add_circle_outline,
          color: Color(0xFFE53935), size: 40),
      title: const Text('Criar Nova Rota'),
      subtitle: const Text('Adicionar um novo trajeto'),
      onTap: () {
        // 🔹 ATUALIZADO: Verifica se a van está cadastrada ANTES de navegar
        final veiculo = motoristaData['veiculo'];
        final vanCadastrada =
            veiculo != null && veiculo is String && veiculo.isNotEmpty;

        if (vanCadastrada) {
          // Envia null para o ID, indicando modo de criação
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CriarRotaScreen()),
          );
        } else {
          // 🔹 ATUALIZADO: Mostra aviso se não houver van
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
  Widget _buildGerenciamentoAlunos(Map<String, dynamic> motoristaData) {
    final List<String> alunosIds =
        List<String>.from(motoristaData['alunosIds'] ?? []);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          // 🔹 ATUALIZADO: Tamanho do ícone padronizado
          leading: const Icon(Icons.people_outline,
              color: Color(0xFFE53935), size: 40),
          title: const Text("Alunos Vinculados"),
          subtitle: const Text("Ver lista de passageiros e solicitações"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          // 🔹 ATUALIZADO: Navega para a nova tela
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
                  final aluno = Aluno.fromMap(
                      doc.id, doc.data() as Map<String, dynamic>);
                  final nome = aluno.nome ?? 'Aluno sem nome';
                  final faculdade =
                      aluno.faculdade ?? 'Faculdade não informada';

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
    if (_uid == null) {
      return const Scaffold(
        body: Center(
          child: Text("Erro: Usuário não está logado."),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('motoristas')
            .doc(_uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text('Erro: Não foi possível carregar o perfil.'));
          }

          final motoristaData = snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🔹 SEÇÃO 1: Gerenciamento da Van
              _buildSectionTitle(context, 'Gerenciamento do Veículo'),
              Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: _buildGerenciamentoVan(motoristaData),
              ),

              // 🔹 SEÇÃO 2: Gerenciamento de Rotas
              _buildSectionTitle(context, 'Gerenciamento da Rota'),
              Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGerenciamentoRotas(motoristaData),
                    const Divider(height: 1),
                    // 🔹 ATUALIZADO: Passa 'motoristaData'
                    _buildCriarRotaTile(context, motoristaData),
                  ],
                ),
              ),

              // 🔹 ATUALIZADO: SEÇÃO 3: Gerenciamento de Alunos
              _buildSectionTitle(context, 'Alunos'),
              Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: _buildGerenciamentoAlunos(motoristaData),
              ),

              const SizedBox(height: 80), // Espaço para o footer
            ],
          );
        },
      ),
    );
  }
}

