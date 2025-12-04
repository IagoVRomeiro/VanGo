import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:vango/models/chat.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/services/chat_service.dart';

import 'tela_busca_motorista.dart';
import 'tela_chat.dart';
import 'tela_notificacoes.dart';
import '../widgets/neon_app_bar.dart';

class TelaListaChats extends StatefulWidget {
  final bool showAppBar;
  const TelaListaChats({super.key, this.showAppBar = false});

  @override
  State<TelaListaChats> createState() => _TelaListaChatsState();
}

class _TelaListaChatsState extends State<TelaListaChats> {
  User? _currentUser;
  Future<UserRole>? _userRoleFuture;
  Future<_MotoristaVinculadoInfo?>? _motoristaVinculadoFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>> _userDocCache = {};

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _userRoleFuture = _getUserRole(_currentUser!.uid);
      _motoristaVinculadoFuture = _buscarMotoristaVinculado(_currentUser!.uid);
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserDoc(String userId) {
    return _userDocCache.putIfAbsent(
      userId,
      () => _firestore.collection('users').doc(userId).get(),
    );
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                onPressed: onAction,
                child: Text(actionText),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
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

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    if (!widget.showAppBar) return content;

    return Scaffold(
      appBar: NeonAppBar(
        title: 'Conversas',
        onNotificationsPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TelaNotificacoes()),
          );
        },
      ),
      body: content,
    );
  }

  Widget _buildMotoristaChatList(String motoristaId) {
    final theme = Theme.of(context);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('motoristas').doc(motoristaId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data();
        final alunosVinculados =
            List<String>.from(data?['alunosIds'] ?? const <String>[]);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  "Conversas com alunos não vinculados",
                  style: theme.textTheme.titleLarge,
                ),
              ),
              _buildChatListNaoVinculados(
                motoristaId: motoristaId,
                alunosVinculados: alunosVinculados,
              ),
              const Divider(height: 30),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text("Alunos Vinculados", style: theme.textTheme.titleLarge),
              ),
              _buildAlunosVinculadosSection(motoristaId),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatListNaoVinculados({
    required String motoristaId,
    required List<String> alunosVinculados,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: motoristaId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildEmptyState(
            title: 'Erro ao carregar conversas.',
            subtitle: 'Tente novamente mais tarde.',
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(title: 'Nenhuma nova solicitação de contato.');
        }

        final chats = snapshot.data!.docs.where((chat) {
          final participantsRaw = chat['participants'];
          final participants = participantsRaw is List
              ? List<String>.from(participantsRaw)
              : <String>[];
          final otherUserId = participants.firstWhere(
            (id) => id != motoristaId,
            orElse: () => (chat['alunoId'] as String?) ?? '',
          );
          if (otherUserId.isEmpty) return false;
          final status = ChatStatus.fromString(chat['status'] as String?);
          final isAlunoVinculado = alunosVinculados.contains(otherUserId);
          final statusElegivel =
              status == ChatStatus.inquiry || status == ChatStatus.active;
          return !isAlunoVinculado && statusElegivel;
        }).toList()
          ..sort((a, b) {
            final lastA =
                ((a['lastMessage'] as Map<String, dynamic>?)?['timestamp'] as Timestamp?)
                    ?.toDate();
            final lastB =
                ((b['lastMessage'] as Map<String, dynamic>?)?['timestamp'] as Timestamp?)
                    ?.toDate();
            return (lastB ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(lastA ?? DateTime.fromMillisecondsSinceEpoch(0));
          });

        if (chats.isEmpty) {
          return _buildEmptyState(title: 'Nenhuma nova solicitação de contato.');
        }

        return AnimationLimiter(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final participantsRaw = chat['participants'];
              final participants = participantsRaw is List
                  ? List<String>.from(participantsRaw)
                  : <String>[];
              final otherUserId = participants.firstWhere(
                (id) => id != motoristaId,
                orElse: () => (chat['alunoId'] as String?) ?? '',
              );
              if (otherUserId.isEmpty) return const SizedBox.shrink();
              final lastMessage = chat['lastMessage'] as Map<String, dynamic>? ?? {};
              final status = ChatStatus.fromString(chat['status'] as String?);

              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: FutureBuilder<DocumentSnapshot>(
                      future: _getUserDoc(otherUserId),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                          return const SizedBox.shrink();
                        }
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        final nome = userData['nome'] ?? 'Usuário Desconhecido';
                        final fotoUrl = userData['fotoUrl'] as String?;
                        final timestamp = lastMessage['timestamp'] as Timestamp?;

                        return Card.filled(
                          color: status == ChatStatus.inquiry
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.5)
                              : null,
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              status == ChatStatus.inquiry
                                  ? 'Aluno ainda não vinculado'
                                  : (lastMessage['text'] ?? 'Toque para responder.'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              timestamp != null
                                  ? DateFormat('HH:mm').format(timestamp.toDate())
                                  : '',
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
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAlunoChatView(String alunoId) {
    final motoristaFuture =
        _motoristaVinculadoFuture ??= _buscarMotoristaVinculado(alunoId);

    return FutureBuilder<_MotoristaVinculadoInfo?>(
      future: motoristaFuture,
      builder: (context, motoristaSnapshot) {
        if (motoristaSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final motoristaInfo = motoristaSnapshot.data;

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

            final chats = snapshot.data?.docs ?? [];
            final children = <Widget>[];

            if (motoristaInfo != null) {
              children.add(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Seu motorista vinculado',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Card.filled(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4),
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withValues(alpha: 0.6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: motoristaInfo.fotoUrl != null &&
                                  motoristaInfo.fotoUrl!.isNotEmpty
                              ? NetworkImage(motoristaInfo.fotoUrl!)
                              : null,
                          child: motoristaInfo.fotoUrl == null ||
                                  motoristaInfo.fotoUrl!.isEmpty
                              ? const Icon(Icons.drive_eta)
                              : null,
                        ),
                        title: Text(
                          motoristaInfo.nome,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Toque aqui para iniciar ou retomar a conversa.',
                        ),
                        trailing: const Icon(Icons.chat_bubble_outline),
                        onTap: () => _abrirChatComMotorista(
                          alunoId: alunoId,
                          motoristaId: motoristaInfo.motoristaId,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (chats.isEmpty && motoristaInfo == null) {
              children.add(
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: _buildEmptyState(
                    title: 'Nenhuma conversa',
                    subtitle:
                        'Inicie uma conversa com um motorista para que ela apareça aqui.',
                    actionText: 'Encontrar Motoristas',
                    onAction: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const TelaBuscaMotorista()),
                      );
                    },
                  ),
                ),
              );
            }

            if (chats.isNotEmpty) {
              for (final chat in chats) {
                final participants = List<String>.from(chat['participants']);
                final motoristaId =
                    participants.firstWhere((id) => id != alunoId);
                final lastMessage =
                    chat['lastMessage'] as Map<String, dynamic>? ?? {};
                final status = ChatStatus.fromString(chat['status'] as String?);

                children.add(
                  FutureBuilder<DocumentSnapshot>(
                    future: _getUserDoc(motoristaId),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData ||
                          !(userSnapshot.data?.exists ?? false)) {
                        return const SizedBox.shrink();
                      }
                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      final nomeMotorista =
                          userData['nome'] ?? 'Motorista Desconhecido';
                      final fotoUrl = userData['fotoUrl'] as String?;
                      final timestamp = lastMessage['timestamp'] as Timestamp?;

                      return Card.filled(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 4.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                fotoUrl != null && fotoUrl.isNotEmpty
                                    ? NetworkImage(fotoUrl)
                                    : null,
                            child: fotoUrl == null || fotoUrl.isEmpty
                                ? const Icon(Icons.drive_eta)
                                : null,
                          ),
                          title: Text(
                            nomeMotorista,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            status == ChatStatus.inquiry
                                ? 'Você ainda não está vinculado a este motorista'
                                : (lastMessage['text'] ??
                                    'Toque para responder.'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                timestamp != null
                                    ? DateFormat('HH:mm')
                                        .format(timestamp.toDate())
                                    : '',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                              if (status == ChatStatus.inquiry)
                                Text(
                                  'Não vinculado',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall,
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
                  ),
                );
              }
            }

            if (children.isEmpty) {
              return const SizedBox.shrink();
            }

            return AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                itemCount: children.length,
                itemBuilder: (context, index) {
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: children[index],
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

        return FutureBuilder<_AlunosRotasData>(
          future: _buscarUsuariosERotas(alunosIds, motoristaId),
          builder: (context, snapshotDados) {
            if (snapshotDados.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ));
            }
            final dados = snapshotDados.data;
            final usuarios = dados?.usuarios ?? [];
            final rotasPorAluno = dados?.rotasPorAluno ?? {};
            if (usuarios.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Não foi possível carregar os dados dos alunos.'),
              );
            }

            return AnimationLimiter(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                itemCount: usuarios.length,
                itemBuilder: (context, index) {
                  final usuario = usuarios[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Card(
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
                            subtitle: Text(
                              [
                                usuario.endereco ?? 'Endereço não informado',
                                'Rota: ${(rotasPorAluno[usuario.id]?.join(", ") ?? 'Não vinculada')}',
                              ].join('\n'),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.chat_bubble_outline),
                              tooltip: 'Conversar',
                              onPressed: () => _abrirChatComAluno(usuario.id, motoristaId),
                            ),
                            onTap: () => _abrirChatComAluno(usuario.id, motoristaId),
                            onLongPress: () => _desvincularMotorista(usuario.id, motoristaId),
                          ),
                        ),
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
  }

  Future<_MotoristaVinculadoInfo?> _buscarMotoristaVinculado(
      String alunoId) async {
    try {
      final alunoDoc =
          await _firestore.collection('alunos').doc(alunoId).get();
      final alunoData = alunoDoc.data();
      if (alunoData == null) {
        return null;
      }
      final motoristaId = alunoData['motoristaId'] as String?;
      if (motoristaId == null || motoristaId.isEmpty) {
        return null;
      }

      final usuarioDoc =
          await _firestore.collection('users').doc(motoristaId).get();
      final usuarioData = usuarioDoc.data();
      if (usuarioData == null) {
        return null;
      }

      return _MotoristaVinculadoInfo(
        motoristaId: motoristaId,
        nome: usuarioData['nome'] ?? 'Motorista vinculado',
        fotoUrl: usuarioData['fotoUrl'] as String?,
      );
    } catch (e) {
      debugPrint('Erro ao buscar motorista vinculado: $e');
      return null;
    }
  }

  Future<void> _desvincularMotorista(String alunoId, String motoristaId) async {
    try {
      await _firestore.collection('alunos').doc(alunoId).update({
        'motoristaId': FieldValue.delete(),
      });
      await _firestore.collection('motoristas').doc(motoristaId).update({
        'alunosIds': FieldValue.arrayRemove([alunoId]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Desvinculado com sucesso.')),
        );
        setState(() {}); // força rebuild para atualizar seção de motorista vinculado
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao desvincular: $e')),
        );
      }
    }
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

  Future<_AlunosRotasData> _buscarUsuariosERotas(
      List<String> ids, String motoristaId) async {
    final usuarios = await _buscarUsuariosPorIds(ids);
    final rotas = await _buscarRotasPorMotorista(motoristaId);
    return _AlunosRotasData(usuarios: usuarios, rotasPorAluno: rotas);
  }

  Future<Map<String, List<String>>> _buscarRotasPorMotorista(
      String motoristaId) async {
    final snapshot = await _firestore
        .collection('rotas')
        .where('motoristaId', isEqualTo: motoristaId)
        .get();

    final Map<String, List<String>> mapa = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final nome = data['nome'] as String? ?? 'Rota sem nome';
      final alunos = List<String>.from(data['listaAlunosIds'] ?? []);
      for (final alunoId in alunos) {
        mapa.putIfAbsent(alunoId, () => []).add(nome);
      }
    }
    return mapa;
  }

  Future<void> _abrirChatComMotorista({
    required String alunoId,
    required String motoristaId,
  }) async {
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
            recipientId: motoristaId,
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

class _AlunosRotasData {
  final List<Usuario> usuarios;
  final Map<String, List<String>> rotasPorAluno;

  const _AlunosRotasData({
    required this.usuarios,
    required this.rotasPorAluno,
  });
}

class _MotoristaVinculadoInfo {
  final String motoristaId;
  final String nome;
  final String? fotoUrl;

  const _MotoristaVinculadoInfo({
    required this.motoristaId,
    required this.nome,
    this.fotoUrl,
  });
}
