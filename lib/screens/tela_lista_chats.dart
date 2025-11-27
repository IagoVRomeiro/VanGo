import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/services/chat_service.dart';

import 'tela_busca_motorista.dart';
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
      debugPrint('Erro ao buscar role do usuário: $e');
      return UserRole.indefinido;
    }
  }

  Widget _buildEmptyState({required String title, String? subtitle, VoidCallback? onAction, String? actionText}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ]
          ],
        ),
      ),
    );
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

          const Divider(height: 30),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text("Alunos Vinculados", style: Theme.of(context).textTheme.titleLarge),
          ),
          _buildAlunosVinculadosSection(motoristaId),
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
          return _buildEmptyState(title: emptyMessage);
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
            final status = chat['status'] as String? ?? 'active';

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
                      status == 'inquiry'
                          ? 'Solicitação pendente'
                          : (lastMessage['text'] ?? 'Toque para responder.'),
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
          return _buildEmptyState(
            title: 'Nenhuma conversa',
            subtitle: 'Inicie uma conversa com um motorista para que ela apareça aqui.',
            actionText: 'Encontrar Motoristas',
            onAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TelaBuscaMotorista()),
              );
            },
          );
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
            final status = chat['status'] as String? ?? 'active';

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
                      status == 'inquiry'
                          ? 'Aguardando aprovação do motorista'
                          : (lastMessage['text'] ?? 'Toque para responder.'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (status == 'inquiry')
                          Text(
                            'Pendente',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
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

  Widget _buildAlunosVinculadosSection(String motoristaId) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _firestore.collection('motoristas').doc(motoristaId).get(),
      builder: (context, motoristaSnapshot) {
        if (motoristaSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ));
        }

        if (!motoristaSnapshot.hasData || !motoristaSnapshot.data!.exists) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Não foi possível carregar os alunos vinculados.'),
          );
        }

        final data = motoristaSnapshot.data!.data();
        final alunosIds = List<String>.from(data?['alunosIds'] ?? []);

        if (alunosIds.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Text('Nenhum aluno vinculado no momento.'),
          );
        }

        return FutureBuilder<List<Usuario>>(
          future: _buscarUsuariosPorIds(alunosIds),
          builder: (context, alunoUsuariosSnapshot) {
            if (alunoUsuariosSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ));
            }
            final usuarios = alunoUsuariosSnapshot.data ?? [];
            if (usuarios.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Não foi possível carregar os dados dos alunos.'),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              itemCount: usuarios.length,
              itemBuilder: (context, index) {
                final usuario = usuarios[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: usuario.fotoUrl != null && usuario.fotoUrl!.isNotEmpty
                          ? NetworkImage(usuario.fotoUrl!)
                          : null,
                      child: usuario.fotoUrl == null || usuario.fotoUrl!.isEmpty
                          ? Text(usuario.nome.isNotEmpty ? usuario.nome[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text(usuario.nome, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text(usuario.endereco ?? 'Endereço não informado'),
                    trailing: IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      tooltip: 'Conversar',
                      onPressed: () => _abrirChatComAluno(usuario.id, motoristaId),
                    ),
                    onTap: () => _abrirChatComAluno(usuario.id, motoristaId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<Usuario>> _buscarUsuariosPorIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    const chunkSize = 10;
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize) > ids.length ? ids.length : i + chunkSize;
      futures.add(
        _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: ids.sublist(i, end))
            .get(),
      );
    }

    final snapshots = await Future.wait(futures);
    final usuarios = <Usuario>[];
    for (final snapshot in snapshots) {
      usuarios.addAll(snapshot.docs.map((doc) => Usuario.fromSnapshot(doc)));
    }
    usuarios.sort((a, b) => a.nome.compareTo(b.nome));
    return usuarios;
  }

  Future<void> _abrirChatComAluno(String alunoId, String motoristaId) async {
    try {
      final chatId = await ChatService.ensureChat(
        alunoId: alunoId,
        motoristaId: motoristaId,
        activate: true,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TelaChat(
            chatId: chatId,
            recipientId: alunoId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir chat: $e')),
        );
      }
    }
  }
}
