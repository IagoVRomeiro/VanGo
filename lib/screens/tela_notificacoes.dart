import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/usuario.dart'; // Importa Usuario para pegar o Role

class TelaNotificacoes extends StatefulWidget {
   // OK: Removido 'const' no construtor da classe anterior
   TelaNotificacoes({super.key});

  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  User? _currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<UserRole>? _userRoleFuture;
  
  // 🔹 Definição das cores para melhor controle
  final Color _alunoColor = Colors.amber;
  final Color _motoristaColor = const Color(0xFFE53935);

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
     final alunoId = _currentUser?.uid;
     if (alunoId == null) return;
      try {
        await _firestore.runTransaction((transaction) async {
          final contratoRef = _firestore.collection('contratos').doc(contratoId);
          transaction.update(contratoRef, {'status': 'aprovado'});
          final motoristaRef = _firestore.collection('motoristas').doc(motoristaId);
          transaction.update(motoristaRef, {'alunosIds': FieldValue.arrayUnion([alunoId])});
          final alunoRef = _firestore.collection('alunos').doc(alunoId);
          transaction.update(alunoRef, {'motoristaId': motoristaId});
        });
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vinculado!'), backgroundColor: Colors.green));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
  }

  Future<void> _recusarConviteAluno(String contratoId) async {
     try {
      await _firestore.collection('contratos').doc(contratoId).delete();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recusado.'), backgroundColor: Colors.grey));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _aceitarSolicitacaoMotorista(String contratoId, String alunoId) async {
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
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aceito!'), backgroundColor: Colors.green));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
  }

   Future<void> _recusarSolicitacaoMotorista(String contratoId) async {
      try {
        await _firestore.collection('contratos').doc(contratoId).delete();
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recusado.'), backgroundColor: Colors.grey));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
  }
  // --- Fim da Lógica ---

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notificações'),
          backgroundColor: _alunoColor, // Cor padrão
          foregroundColor: Colors.white,
        ),
        body: _buildLoginPrompt(context),
      );
    }
    
    // 🎯 CORREÇÃO: Usa FutureBuilder para definir a AppBar e o Body de uma vez
    return FutureBuilder<UserRole>(
      future: _userRoleFuture,
      builder: (context, snapshot) {
        // Define a cor da AppBar com base no resultado (ou padrão)
        final UserRole userRole = snapshot.data ?? UserRole.indefinido;
        final Color appBarColor = userRole == UserRole.motorista ? _motoristaColor : _alunoColor;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notificações'),
            backgroundColor: appBarColor,
            foregroundColor: Colors.white,
            // Adiciona o botão de voltar se a tela pode ser fechada
            leading: Navigator.canPop(context) ? const BackButton(color: Colors.white) : null,
          ),
          body: _buildBody(snapshot, userRole),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<UserRole> snapshot, UserRole userRole) {
     if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || !snapshot.hasData || userRole == UserRole.indefinido) {
        return const Center(child: Text('Não foi possível carregar suas notificações.'));
      }

      // Se o papel do usuário foi carregado:
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

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: notificationSnapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final contrato = notificationSnapshot.data!.docs[index];
              final data = contrato.data() as Map<String, dynamic>;
              final contratoId = contrato.id;

              if (userRole == UserRole.aluno) {
                final motoristaId = data['motoristaId'] as String?;
                if(motoristaId == null) return const SizedBox.shrink();
                return _buildAlunoNotificationCard(contratoId, motoristaId);
              } else {
                final alunoId = data['alunoId'] as String?;
                if(alunoId == null) return const SizedBox.shrink();
                return _buildMotoristaNotificationCard(contratoId, alunoId);
              }
            },
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
      return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('alunos').doc(alunoId).get(),
      builder: (context, alunoSnapshot) {
        if (!alunoSnapshot.hasData || !alunoSnapshot.data!.exists) {
          return const ListTile(title: Text('Carregando solicitação...'));
        }
        // 🚨 ATENÇÃO: É necessário que a classe Aluno.fromMap e Aluno estejam disponíveis
        // Como não as temos, vou usar um placeholder para Aluno.
        final data = alunoSnapshot.data!.data() as Map<String, dynamic>;
        final nomeAluno = data['nome'] ?? 'Aluno Desconhecido';
        final fotoUrl = data['fotoUrl'] as String?;
        final primeiraLetra = nomeAluno.isNotEmpty ? nomeAluno[0] : 'A';

         return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: ListTile(
             leading: CircleAvatar(
              backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
              child: fotoUrl == null ? Text(primeiraLetra) : null,
            ),
            title: Text(nomeAluno),
            subtitle: const Text('Enviou uma solicitação de vínculo.'),
             trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: 'Aceitar',
                  onPressed: () => _aceitarSolicitacaoMotorista(contratoId, alunoId),
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
              backgroundColor: _alunoColor,
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
