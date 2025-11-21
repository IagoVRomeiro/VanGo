import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vango/models/usuario.dart';

import 'tela_chat.dart';

class TelaListaChats extends StatefulWidget {
  const TelaListaChats({super.key});

  @override
  State<TelaListaChats> createState() => _TelaListaChatsState();
}

class _TelaListaChatsState extends State<TelaListaChats> {
  User? _currentUser;
  Future<UserRole>? _userRoleFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _userRoleFuture = _getUserRole(_currentUser!.uid);
    }
  }

  Future<UserRole> _getUserRole(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserRole.fromString(doc.data()?['role']);
      }
      return UserRole.indefinido;
    } catch (e) {
      // Log the error
      return UserRole.indefinido;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(child: Text('Faça login para ver suas conversas.'));
    }

    return FutureBuilder<UserRole>(
      future: _userRoleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == UserRole.indefinido) {
          return const Center(child: Text('Não foi possível determinar o seu perfil.'));
        }

        final userRole = snapshot.data!;
        if (userRole == UserRole.motorista) {
          return _buildMotoristaChatList(_currentUser!.uid);
        } else {
          return _buildAlunoChatView(_currentUser!.uid);
        }
      },
    );
  }

  Widget _buildMotoristaChatList(String motoristaId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: motoristaId)
          .orderBy('lastMessage.timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Nenhuma conversa encontrada.'));
        }

        final chats = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final participants = List<String>.from(chat['participants']);
            final alunoId = participants.firstWhere((id) => id != motoristaId);
            final lastMessage = chat['lastMessage'] as Map<String, dynamic>? ?? {};

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(alunoId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const SizedBox.shrink(); // Don't show anything if user data is loading/missing
                }
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final nomeAluno = userData['nome'] ?? 'Aluno Desconhecido';
                final fotoUrl = userData['fotoUrl'] as String?;
                final timestamp = lastMessage['timestamp'] as Timestamp?;

                return Card.filled(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty
                          ? NetworkImage(fotoUrl)
                          : null,
                      child: fotoUrl == null || fotoUrl.isEmpty
                          ? Text(nomeAluno.isNotEmpty ? nomeAluno[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text(
                      nomeAluno,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      lastMessage['texto'] ?? 'Nenhuma mensagem ainda.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    trailing: Text(
                      timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TelaChat(
                            chatId: chat.id,
                            nomeReceptor: nomeAluno,
                            receptorId: alunoId,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAlunoChatView(String alunoId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('alunos').doc(alunoId).get(),
      builder: (context, alunoSnapshot) {
        if (alunoSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!alunoSnapshot.hasData || !alunoSnapshot.data!.exists) {
          return const Center(child: Text('Perfil de aluno não encontrado.'));
        }

        final alunoData = alunoSnapshot.data!.data() as Map<String, dynamic>;
        final motoristaId = alunoData['motoristaId'] as String?;

        if (motoristaId == null || motoristaId.isEmpty) {
          return const Center(child: Text('Você ainda não está vinculado a um motorista.'));
        }

        // Se tem motorista, busca os dados dele
        return FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(motoristaId).get(),
          builder: (context, motoristaSnapshot) {
            if (motoristaSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!motoristaSnapshot.hasData || !motoristaSnapshot.data!.exists) {
              return const Center(child: Text('Não foi possível encontrar seu motorista.'));
            }

            final motoristaData = motoristaSnapshot.data!.data() as Map<String, dynamic>;
            final nomeMotorista = motoristaData['nome'] ?? 'Motorista';
            final fotoUrl = motoristaData['fotoUrl'] as String?;

            final ids = [motoristaId, alunoId]..sort();
            final chatId = ids.join('_');

            // Exibe a conversa com o motorista
            return ListView(
              padding: const EdgeInsets.all(8.0),
              children: [
                Card.filled(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty
                          ? NetworkImage(fotoUrl)
                          : null,
                      child: fotoUrl == null || fotoUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(
                      nomeMotorista, 
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Toque para iniciar a conversa',
                       style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TelaChat(
                            chatId: chatId,
                            nomeReceptor: nomeMotorista,
                            receptorId: motoristaId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}