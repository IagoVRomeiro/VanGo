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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seção de Solicitações
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Solicitações de Contato", style: Theme.of(context).textTheme.titleLarge),
          ),
          _buildChatList(
            motoristaId: motoristaId,
            status: 'inquiry',
            emptyMessage: 'Nenhuma nova solicitação de contato.',
          ),

          const Divider(height: 30),

          // Seção de Conversas Ativas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text("Conversas", style: Theme.of(context).textTheme.titleLarge),
          ),
          _buildChatList(
            motoristaId: motoristaId,
            status: 'active', // ou 'aprovado', dependendo da sua convenção
            emptyMessage: 'Nenhuma conversa ativa.',
          ),
        ],
      ),
    );
  }

  // Widget reutilizável para construir cada lista de chat
  Widget _buildChatList({required String motoristaId, required String status, required String emptyMessage}) {
     return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: motoristaId)
          .where('status', isEqualTo: status)
          .orderBy('lastMessage.timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(emptyMessage),
          ));
        }

        final chats = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final participants = List<String>.from(chat['participants']);
            final otherUserId = participants.firstWhere((id) => id != motoristaId);
            final lastMessage = chat['lastMessage'] as Map<String, dynamic>? ?? {};

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(otherUserId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final nome = userData['nome'] ?? 'Usuário Desconhecido';
                final fotoUrl = userData['fotoUrl'] as String?;
                final timestamp = lastMessage['timestamp'] as Timestamp?;

                return Card.filled(
                  color: status == 'inquiry' ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5) : null,
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty
                          ? NetworkImage(fotoUrl)
                          : null,
                      child: fotoUrl == null || fotoUrl.isEmpty
                          ? Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text(
                      nome,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      lastMessage['text'] ?? 'Toque para responder.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                            recipientId: otherUserId,
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
    // A view do aluno agora também busca na coleção de chats
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: alunoId)
          .orderBy('lastMessage.timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Nenhuma conversa encontrada. Inicie uma conversa na tela de busca de motoristas!'));
        }

        final chats = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final participants = List<String>.from(chat['participants']);
            final motoristaId = participants.firstWhere((id) => id != alunoId);
            final lastMessage = chat['lastMessage'] as Map<String, dynamic>? ?? {};

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(motoristaId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final nomeMotorista = userData['nome'] ?? 'Motorista Desconhecido';
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
                          ? const Icon(Icons.drive_eta)
                          : null,
                    ),
                    title: Text(
                      nomeMotorista,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      lastMessage['text'] ?? 'Toque para responder.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                            recipientId: motoristaId,
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
}