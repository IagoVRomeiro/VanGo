import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/aluno.dart'; // Importa o modelo Aluno
import '../models/motorista.dart'; // Importa Motorista para desvincular

/// Tela para o motorista gerenciar alunos vinculados, convites e solicitações.
class TelaGerenciarAlunos extends StatefulWidget {
  const TelaGerenciarAlunos({super.key});

  @override
  State<TelaGerenciarAlunos> createState() => _TelaGerenciarAlunosState();
}

class _TelaGerenciarAlunosState extends State<TelaGerenciarAlunos> {
  String? _motoristaId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _emailController = TextEditingController();
  bool _isConvidando = false;

  @override
  void initState() {
    super.initState();
    _motoristaId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // --- Lógica de Aceitar/Recusar Solicitação ---
  // (Mantida para ser usada pelas notificações ou futuras implementações)
  Future<void> _aceitarSolicitacao(String contratoId, String alunoId) async {
    if (_motoristaId == null) return;
    try {
      await _firestore.runTransaction((transaction) async {
        final contratoRef = _firestore.collection('contratos').doc(contratoId);
        transaction.update(contratoRef, {'status': 'aprovado'});
        final motoristaRef =
            _firestore.collection('motoristas').doc(_motoristaId);
        transaction.update(motoristaRef, {
          'alunosIds': FieldValue.arrayUnion([alunoId])
        });
        final alunoRef = _firestore.collection('alunos').doc(alunoId);
        transaction.update(alunoRef, {'motoristaId': _motoristaId});
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Aluno vinculado com sucesso!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao aceitar solicitação: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _recusarSolicitacao(String contratoId) async {
    try {
      await _firestore.collection('contratos').doc(contratoId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Solicitação recusada.'),
              backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao recusar solicitação: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
  // --- Fim Aceitar/Recusar ---

  // --- Lógica de Enviar Convite ---
  Future<void> _enviarConvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, digite um email.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    if (_motoristaId == null) return;

    setState(() => _isConvidando = true);

    try {
      // 1. Encontra o usuário (aluno) pelo email
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'aluno')
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('Aluno não encontrado ou não cadastrado.');
      }

      final alunoId = userQuery.docs.first.id;

      // 2. Verifica se o aluno já está vinculado
      final motoristaDoc =
          await _firestore.collection('motoristas').doc(_motoristaId).get();
      final alunosIds =
          List<String>.from(motoristaDoc.data()?['alunosIds'] ?? []);
      if (alunosIds.contains(alunoId)) {
        throw Exception('Este aluno já está vinculado a você.');
      }

      // 3. Verifica se já existe um contrato pendente ou convite
      final contratoQuery = await _firestore
          .collection('contratos')
          .where('motoristaId', isEqualTo: _motoristaId)
          .where('alunoId', isEqualTo: alunoId)
          .where('status', whereIn: ['pendente', 'convite_motorista'])
          .limit(1)
          .get();

      if (contratoQuery.docs.isNotEmpty) {
        throw Exception('Um convite ou solicitação para este aluno já existe.');
      }

      // 4. Cria o novo contrato (convite)
      await _firestore.collection('contratos').add({
        'motoristaId': _motoristaId,
        'alunoId': alunoId,
        'status': 'convite_motorista', // Status para o aluno aceitar
        'dataSolicitacao': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Convite enviado com sucesso!'),
              backgroundColor: Colors.green),
        );
        _emailController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao convidar: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConvidando = false);
      }
    }
  }
  // --- Fim Enviar Convite ---

  // 🔹 NOVO: Lógica para Desvincular Aluno
  Future<void> _desvincularAluno(String alunoId) async {
    if (_motoristaId == null) return;

    // Confirmação
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Desvinculação'),
        content: const Text('Tem certeza que deseja desvincular este aluno? O contrato será removido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desvincular', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Remove o ID do aluno do array 'alunosIds' do motorista
        final motoristaRef =
            _firestore.collection('motoristas').doc(_motoristaId);
        transaction.update(motoristaRef, {
          'alunosIds': FieldValue.arrayRemove([alunoId])
        });

        // 2. Remove o 'motoristaId' do documento do aluno
        final alunoRef = _firestore.collection('alunos').doc(alunoId);
        transaction.update(alunoRef, {'motoristaId': FieldValue.delete()}); // Remove o campo

        // 3. Encontra e deleta o contrato aprovado entre eles
        final contratoQuery = await _firestore
            .collection('contratos')
            .where('motoristaId', isEqualTo: _motoristaId)
            .where('alunoId', isEqualTo: alunoId)
            .where('status', isEqualTo: 'aprovado') // Garante que é o aprovado
            .limit(1)
            .get();

        if (contratoQuery.docs.isNotEmpty) {
          final contratoRef = contratoQuery.docs.first.reference;
          transaction.delete(contratoRef);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Aluno desvinculado com sucesso.'),
              backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao desvincular aluno: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
  // --- Fim Desvincular Aluno ---

  @override
  Widget build(BuildContext context) {
    if (_motoristaId == null) {
      return const Center(child: Text('Erro: Motorista não está logado.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------------------------------------------
          // 🔹 ATUALIZADO: Seção 1: Lista de Alunos Vinculados
          // -------------------------------------------
          Text(
            'Lista de Alunos Vinculados', // 🔹 TÍTULO ALTERADO
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildListaAlunosVinculados(), // 🔹 FUNÇÃO ALTERADA
          const Divider(height: 40),

          // -------------------------------------------
          // Seção 2: Enviar Convite
          // -------------------------------------------
          Text(
            'Convidar Aluno',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email do Aluno',
              hintText: 'Digite o email para convidar',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isConvidando ? null : _enviarConvite,
            icon: _isConvidando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: Text(_isConvidando ? 'ENVIANDO...' : 'ENVIAR CONVITE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const Divider(height: 40),

          // -------------------------------------------
          // Seção 3: Convites Enviados
          // -------------------------------------------
          Text(
            'Convites Enviados',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildListaConvitesEnviados(),
        ],
      ),
    );
  }

  // 🔹 ATUALIZADO: Constrói a lista de alunos VINCULADOS (aprovados)
  Widget _buildListaAlunosVinculados() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('contratos')
          .where('motoristaId', isEqualTo: _motoristaId)
          .where('status', isEqualTo: 'aprovado') // 🔹 QUERY ALTERADA
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Nenhum aluno vinculado no momento.'), // 🔹 TEXTO ALTERADO
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final contrato = snapshot.data!.docs[index];
            final data = contrato.data() as Map<String, dynamic>;
            final alunoId = data['alunoId'] as String?;
            // final contratoId = contrato.id; // Não precisamos mais do contratoId aqui

            if (alunoId == null) return const SizedBox.shrink();

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('alunos').doc(alunoId).get(),
              builder: (context, alunoSnapshot) {
                if (!alunoSnapshot.hasData || !alunoSnapshot.data!.exists) {
                  return const ListTile(
                      title: Text('Carregando dados do aluno...'));
                }

                final aluno = Aluno.fromMap(alunoSnapshot.data!.id,
                    alunoSnapshot.data!.data() as Map<String, dynamic>);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text(aluno.nome ?? 'Aluno sem nome'),
                    subtitle:
                        Text(aluno.faculdade ?? 'Faculdade não informada'),
                    // 🔹 BOTÕES ALTERADOS: Agora mostra botão de desvincular
                    trailing: IconButton(
                          icon:
                              const Icon(Icons.link_off, color: Colors.grey),
                          tooltip: 'Desvincular Aluno',
                          onPressed: () => _desvincularAluno(alunoId),
                        ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  // --- Fim da lista de alunos vinculados ---

  // Widget para construir a lista de convites enviados ...
  Widget _buildListaConvitesEnviados() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('contratos')
          .where('motoristaId', isEqualTo: _motoristaId)
          .where('status', isEqualTo: 'convite_motorista')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Nenhum convite enviado pendente.'),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final contrato = snapshot.data!.docs[index];
            final data = contrato.data() as Map<String, dynamic>;
            final alunoId = data['alunoId'] as String?;
            final contratoId = contrato.id;

            if (alunoId == null) return const SizedBox.shrink();

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('alunos').doc(alunoId).get(),
              builder: (context, alunoSnapshot) {
                if (!alunoSnapshot.hasData || !alunoSnapshot.data!.exists) {
                  return const ListTile(
                      title: Text('Carregando dados do aluno...'));
                }

                final aluno = Aluno.fromMap(alunoSnapshot.data!.id,
                    alunoSnapshot.data!.data() as Map<String, dynamic>);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text(aluno.nome ?? 'Aluno sem nome'),
                    subtitle:
                        Text(aluno.faculdade ?? 'Faculdade não informada'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Chip(label: Text('Pendente')),
                        IconButton(
                          icon:
                              const Icon(Icons.delete_outline, color: Colors.grey),
                          tooltip: 'Cancelar Convite',
                          // Usa a mesma lógica de recusar solicitação para cancelar
                          onPressed: () => _recusarSolicitacao(contratoId),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  // Fim do widget de convites enviados
}

