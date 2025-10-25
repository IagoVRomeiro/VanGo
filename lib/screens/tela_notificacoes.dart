// lib/screens/tela_notificacoes.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/motorista.dart';

class TelaNotificacoes extends StatefulWidget {
  const TelaNotificacoes({super.key});

  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  String? _alunoId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _alunoId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _aceitarConvite(String contratoId, String motoristaId) async {
    if (_alunoId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final contratoRef = _firestore.collection('contratos').doc(contratoId);
        transaction.update(contratoRef, {'status': 'aprovado'});

        final motoristaRef =
            _firestore.collection('motoristas').doc(motoristaId);
        transaction.update(motoristaRef, {
          'alunosIds': FieldValue.arrayUnion([_alunoId])
        });

        final alunoRef = _firestore.collection('alunos').doc(_alunoId);
        transaction.update(alunoRef, {'motoristaId': motoristaId});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você foi vinculado ao motorista!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aceitar convite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _recusarConvite(String contratoId) async {
    try {
      await _firestore.collection('contratos').doc(contratoId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Convite recusado.'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao recusar convite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: _alunoId == null
          ? const Center(
              child: Text("Faça login para ver suas notificações."),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('contratos')
                  .where('alunoId', isEqualTo: _alunoId)
                  .where('status', isEqualTo: 'convite_motorista')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhuma notificação nova.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final contrato = snapshot.data!.docs[index];
                    final data = contrato.data() as Map<String, dynamic>;
                    final motoristaId = data['motoristaId'] as String?;
                    final contratoId = contrato.id;

                    if (motoristaId == null) {
                      return const ListTile(
                          title: Text('Erro: Convite inválido'));
                    }

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore
                          .collection('motoristas')
                          .doc(motoristaId)
                          .get(),
                      builder: (context, motoristaSnapshot) {
                        if (!motoristaSnapshot.hasData ||
                            !motoristaSnapshot.data!.exists) {
                          return const ListTile(
                              title: Text('Carregando convite...'));
                        }

                        final motorista = Motorista.fromMap(
                          motoristaSnapshot.data!.id,
                          motoristaSnapshot.data!.data()
                              as Map<String, dynamic>,
                        );

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 4.0, horizontal: 8.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: motorista.fotoUrl != null
                                  ? NetworkImage(motorista.fotoUrl!)
                                  : null,
                              child: motorista.fotoUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(motorista.nome),
                            subtitle: const Text(
                                'Enviou um convite para ser seu motorista.'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle,
                                      color: Colors.green),
                                  tooltip: 'Aceitar',
                                  onPressed: () =>
                                      _aceitarConvite(contratoId, motoristaId),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel,
                                      color: Colors.red),
                                  tooltip: 'Recusar',
                                  onPressed: () =>
                                      _recusarConvite(contratoId),
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
            ),
    );
  }
}
