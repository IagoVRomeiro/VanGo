import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../widgets/neon_app_bar.dart';
import 'tela_notificacoes.dart';
import 'package:vango/services/functions_service.dart';

/// Tela para o motorista gerenciar alunos vinculados, convites e solicitações.
class TelaGerenciarAlunos extends StatefulWidget {
  final bool showAppBar;
  const TelaGerenciarAlunos({super.key, this.showAppBar = true});

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

  Future<void> _recusarSolicitacao(String contratoId) async {
     try {
      await _firestore.collection('contratos').doc(contratoId).delete();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitação recusada.'), backgroundColor: Colors.grey));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

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
      final result = await FunctionsService.instance.call<Map<String, dynamic>>(
        'enviarConvite',
        data: {'email': email},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result.data['message'] as String? ?? 'Operação concluída.'),
              backgroundColor: Colors.green),
        );
        _emailController.clear();
      }
    } on FirebaseFunctionsException catch (e) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Erro: ${e.message}'),
                    backgroundColor: Colors.red
                ),
            );
        }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ocorreu um erro inesperado: $e'),
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
    // Confirmação
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Desvinculação'),
        content: const Text(
            'Tem certeza que deseja desvincular este aluno? O contrato será removido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                Text('Desvincular', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      final result = await FunctionsService.instance.call<Map<String, dynamic>>(
        'desvincularAluno',
        data: {'alunoId': alunoId},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.data['message'] as String? ?? 'Aluno desvinculado com sucesso.'),
            backgroundColor: Colors.grey
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro: ${e.message}'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ocorreu um erro inesperado: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
  // --- Fim Desvincular Aluno ---

  @override
  Widget build(BuildContext context) {
    final bodyContent = _motoristaId == null
        ? const Center(child: Text('Erro: Motorista não está logado.'))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lista de Alunos Vinculados',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildListaAlunosVinculados(),
                const Divider(height: 40),
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const Divider(height: 40),
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

    if (!widget.showAppBar) {
      return bodyContent;
    }

    return Scaffold(
      appBar: NeonAppBar(
        title: 'Gerenciar Alunos',
        onNotificationsPressed: _openNotifications,
      ),
      body: bodyContent,
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaNotificacoes()),
    );
  }

  // 🔹 ATUALIZADO: Constrói a lista de alunos VINCULADOS (aprovados)
  Widget _buildListaAlunosVinculados() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('motoristas').doc(_motoristaId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Não foi possível carregar sua lista de alunos.'));
        }

        final data = snapshot.data!.data();
        final alunosIds = List<String>.from(data?['alunosIds'] ?? []);
        if (alunosIds.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Nenhum aluno vinculado no momento.'),
          ));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: alunosIds.length,
          itemBuilder: (context, index) {
            final alunoId = alunosIds[index];
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _firestore.collection('users').doc(alunoId).get(),
              builder: (context, usuarioSnapshot) {
                if (!usuarioSnapshot.hasData || !usuarioSnapshot.data!.exists) {
                  return const ListTile(title: Text('Carregando dados do aluno...'));
                }

                final usuario = Usuario.fromSnapshot(usuarioSnapshot.data!);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text(usuario.nome),
                    subtitle: Text(usuario.endereco ?? 'Endereço não informado'),
                    trailing: IconButton(
                      icon: const Icon(Icons.link_off, color: Colors.grey),
                      tooltip: 'Desvincular Aluno',
                      onPressed: () => _desvincularAluno(usuario.id),
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

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _firestore.collection('users').doc(alunoId).get(),
              builder: (context, usuarioSnapshot) {
                if (!usuarioSnapshot.hasData || !usuarioSnapshot.data!.exists) {
                  return const ListTile(
                      title: Text('Carregando dados do aluno...'));
                }

                final usuario =
                    Usuario.fromSnapshot(usuarioSnapshot.data!);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text(usuario.nome),
                    subtitle: Text(usuario.endereco ?? 'Endereço não informado'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Chip(label: Text('Pendente')),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.grey),
                          tooltip: 'Cancelar Convite',
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
