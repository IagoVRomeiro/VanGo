import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:vango/services/chat_service.dart';
import '../models/usuario.dart'; // Importa Usuario para pegar o Role
import 'package:vango/widgets/neon_app_bar.dart';

class TelaNotificacoes extends StatefulWidget {
   // OK: Removido 'const' no construtor da classe anterior
   TelaNotificacoes({super.key});

  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  User? _currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  Future<UserRole>? _userRoleFuture;

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
      print("Erro ao buscar role: $e");
      return UserRole.indefinido;
    }
  }

  // --- Lógica de Aceitar/Recusar (inalterada) ---
  Future<void> _aceitarConviteAluno(String contratoId, String motoristaId) async {
     final theme = Theme.of(context);
     final alunoId = _currentUser?.uid;
     if (alunoId == null) return;
      try {
        final callable = _functions.httpsCallable('aceitarConviteAluno');
        final result = await callable.call<Map<String, dynamic>>({
          'contratoId': contratoId,
          'motoristaId': motoristaId,
        });

        await ChatService.ensureChat(
          alunoId: alunoId,
          motoristaId: motoristaId,
          activate: true,
        );

        if (mounted) {
          final message =
              result.data['message'] as String? ?? 'Vínculo confirmado.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
        }
      } on FirebaseFunctionsException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? 'Erro ao aceitar convite.'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: $e'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      }
  }

  Future<void> _recusarConviteAluno(String contratoId) async {
     final theme = Theme.of(context);
     try {
      await _firestore.collection('contratos').doc(contratoId).delete();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Recusado.'), backgroundColor: theme.colorScheme.surfaceVariant));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: theme.colorScheme.error));
    }
  }

  Future<void> _aceitarSolicitacaoMotorista(String contratoId, String alunoId) async {
    final theme = Theme.of(context);
    final motoristaId = _currentUser?.uid;
    if (motoristaId == null) return;
      try {
        await _firestore.runTransaction((transaction) async {
          final contratoRef = _firestore.collection('contratos').doc(contratoId);
          transaction.update(contratoRef, {'status': 'aprovado'});
          final motoristaRef = _firestore.collection('motoristas').doc(motoristaId);
          transaction.update(motoristaRef, {'alunosIds': FieldValue.arrayUnion([alunoId])});
          final alunoRef = _firestore.collection('alunos').doc(alunoId);
          transaction.update(alunoRef, {'motoristaId': motoristaId});
        });
        await ChatService.ensureChat(
          alunoId: alunoId,
          motoristaId: motoristaId,
          activate: true,
        );
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Aceito!'), backgroundColor: theme.colorScheme.primary));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: theme.colorScheme.error));
      }
  }

   Future<void> _recusarSolicitacaoMotorista(String contratoId) async {
      final theme = Theme.of(context);
      try {
        await _firestore.collection('contratos').doc(contratoId).delete();
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Recusado.'), backgroundColor: theme.colorScheme.surfaceVariant));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: theme.colorScheme.error));
      }
  }
  // --- Fim da Lógica ---

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notificações'),
          backgroundColor: Theme.of(context).colorScheme.primary, // Cor padrão
          foregroundColor: Colors.black,
        ),
        body: _buildLoginPrompt(context),
      );
    }
    
    // 🎯 CORREÇÃO: Usa FutureBuilder para definir a AppBar e o Body de uma vez
    return FutureBuilder<UserRole>(
      future: _userRoleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == UserRole.indefinido) {
          return const Scaffold(
            body: Center(child: Text('Não foi possível carregar suas notificações.')),
          );
        }

        final userRole = snapshot.data!;

        return Scaffold(
          appBar: const NeonAppBar(
            title: 'Notificações',
            showMenuButton: false,
            showBackButton: true,
            showNotificationsButton: false,
          ),
          body: _buildBody(userRole),
        );
      },
    );
  }

  Widget _buildBody(UserRole userRole) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getNotificationsStream(userRole, _currentUser!.uid),
      builder: (context, notificationSnapshot) {
        if (notificationSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!notificationSnapshot.hasData || notificationSnapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('Nenhuma notificação nova.', style: TextStyle(fontSize: 16, color: Colors.grey)),
          );
        }

        return AnimationLimiter(
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: notificationSnapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final contrato = notificationSnapshot.data!.docs[index];
              final data = contrato.data() as Map<String, dynamic>;
              final contratoId = contrato.id;

              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: Builder(
                      builder: (context) {
                        if (userRole == UserRole.aluno) {
                          final motoristaId = data['motoristaId'] as String?;
                          if (motoristaId == null) return const SizedBox.shrink();
                          return _buildAlunoNotificationCard(contratoId, motoristaId);
                        } else {
                          final alunoId = data['alunoId'] as String?;
                          if (alunoId == null) return const SizedBox.shrink();
                          return _buildMotoristaNotificationCard(contratoId, alunoId);
                        }
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


  Stream<QuerySnapshot> _getNotificationsStream(UserRole role, String userId) {
    if (role == UserRole.aluno) {
      return _firestore
          .collection('contratos')
          .where('alunoId', isEqualTo: userId)
          .where('status', isEqualTo: 'convite_motorista')
          .snapshots();
    } else {
      return _firestore
          .collection('contratos')
          .where('motoristaId', isEqualTo: userId)
          .where('status', isEqualTo: 'pendente')
          .snapshots();
    }
  }

  Widget _buildAlunoNotificationCard(String contratoId, String motoristaId) {
     return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('motoristas').doc(motoristaId).get(),
      builder: (context, motoristaSnapshot) {
        if (!motoristaSnapshot.hasData || !motoristaSnapshot.data!.exists) {
          return const ListTile(title: Text('Carregando convite...'));
        }
        // 🚨 ATENÇÃO: É necessário que a classe Motorista.fromMap e Motorista estejam disponíveis
        // Como não as temos, vou usar um placeholder para Motorista.
        // O código original dependia delas, mas aqui está a lógica funcional:
        final data = motoristaSnapshot.data!.data() as Map<String, dynamic>;
        final nomeMotorista = data['nome'] ?? 'Motorista Desconhecido';
        final fotoUrl = data['fotoUrl'] as String?;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
              child: fotoUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text(nomeMotorista),
            subtitle: const Text('Enviou um convite para ser seu motorista.'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: 'Aceitar',
                  onPressed: () => _aceitarConviteAluno(contratoId, motoristaId),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  tooltip: 'Recusar',
                  onPressed: () => _recusarConviteAluno(contratoId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMotoristaNotificationCard(String contratoId, String alunoId) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _firestore.collection('users').doc(alunoId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const ListTile(title: Text('Carregando solicitação...'));
        }

        final usuario = Usuario.fromSnapshot(userSnapshot.data!);
        final fotoUrl = usuario.fotoUrl;
        final primeiraLetra = usuario.nome.isNotEmpty ? usuario.nome[0] : 'A';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
              child: fotoUrl == null ? Text(primeiraLetra) : null,
            ),
            title: Text(usuario.nome),
            subtitle: const Text('Enviou uma solicitação de vínculo.'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: 'Aceitar',
                  onPressed: () =>
                      _aceitarSolicitacaoMotorista(contratoId, alunoId),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  tooltip: 'Recusar',
                  onPressed: () => _recusarSolicitacaoMotorista(contratoId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
      return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "Você precisa fazer login para ver as notificações.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14,),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),),
            ),
            child: const Text("Fazer Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),
          ),
        ],
      ),
    );
  }
}
