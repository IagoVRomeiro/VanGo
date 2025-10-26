import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/aluno.dart';
import '../models/motorista.dart';
import 'tela_chat.dart';
import 'tela_perfil.dart';
import 'tela_cadastro.dart';
// 🔹 CORRIGIDO: Importa o nome correto da tela de notificações
import 'tela_notificacoes.dart';

class TelaAluno extends StatefulWidget {
  // 🔹 CORRIGIDO: Removido o 'const' pois StatefulWidget não pode ser const
  // se seus filhos não forem todos const
   TelaAluno({super.key});

  @override
  State<TelaAluno> createState() => _TelaAlunoState();
}

class _TelaAlunoState extends State<TelaAluno> {
  late GoogleMapController mapController;
  final LatLng _initialPosition = const LatLng(-19.9245, -43.9352);
  final Set<Marker> _markers = {};
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _addMarkers();
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao sair: $e")),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _addMarkers() {
    _markers.add(
      Marker(
        markerId: const MarkerId('school'),
        position: _initialPosition,
        infoWindow: const InfoWindow(title: 'Faculdade / Local do Aluno'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    );
  }

  void _onItemTapped(int index) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null && (index == 1 || index == 2)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TelaCadastro()),
      );
      return;
    }

    // Navega para Perfil (índice 2)
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PerfilScreen(collectionPath: 'alunos'),
        ),
      );
    } else { // Muda a aba para Mapa (0) ou Chat (1)
      if (_selectedIndex == index) return;
      setState(() {
        _selectedIndex = index;
      });
    }
  }

    // Helper para definir o título do AppBar
  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return 'Mapa do Aluno';
      case 1: return 'Chat com Motorista';
      // Caso 2 (Perfil) navega, então o título não muda
      default: return _getAppBarTitle(_selectedIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    Widget mapaWidget = Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition:
              CameraPosition(target: _initialPosition, zoom: 14.0),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        leading: user != null
            ? IconButton(
                icon: const Icon(Icons.exit_to_app),
                tooltip: 'Sair',
                onPressed: _logout,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Voltar',
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(_getAppBarTitle(_selectedIndex)),
        // 🔹 ADICIONADO: Botão de notificações
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notificações',
            onPressed: () {
              Navigator.push(
                context,
                // 🔹 CORRIGIDO: Chama a tela correta (sem const)
                MaterialPageRoute(builder: (context) => TelaNotificacoes()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          mapaWidget, // Índice 0
          const AlunoChatWrapper(), // Índice 1
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'), // 0
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'), // 1
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'), // 2
        ],
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

// --- AlunoChatWrapper (sem alterações significativas, mas revisado) ---
class AlunoChatWrapper extends StatefulWidget {
  const AlunoChatWrapper({super.key});

  @override
  State<AlunoChatWrapper> createState() => _AlunoChatWrapperState();
}

class _AlunoChatWrapperState extends State<AlunoChatWrapper> {
  Future<Map<String, dynamic>>? _chatData;

  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser != null) {
      _chatData = _getChatData();
    }
  }

  Future<Map<String, dynamic>> _getChatData() async {
    try {
      final alunoId = FirebaseAuth.instance.currentUser!.uid;
      // 🔹 CORRIGIDO: Acessa o Firestore corretamente
      final alunoDoc =
          await FirebaseFirestore.instance.collection('alunos').doc(alunoId).get();
      if (!alunoDoc.exists) throw Exception('Perfil do aluno não encontrado.');

      final aluno = Aluno.fromMap(alunoDoc.id, alunoDoc.data()!);
      final motoristaId = aluno.motoristaId; // Agora pode ser nulo

      if (motoristaId == null || motoristaId.isEmpty) {
        return {'error': 'Você ainda não está vinculado a um motorista.'};
      }

      // 🔹 CORRIGIDO: Acessa o Firestore corretamente
      final motoristaDoc = await FirebaseFirestore.instance
          .collection('motoristas')
          .doc(motoristaId)
          .get();
      if (!motoristaDoc.exists) throw Exception('Motorista não encontrado.');
      final motorista =
          Motorista.fromMap(motoristaDoc.id, motoristaDoc.data()!);

      final ids = [motoristaId, alunoId]..sort();
      final chatId = ids.join('_');

      return {'chatId': chatId, 'nomeReceptor': motorista.nome};
    } catch (e) {
      return {'error': 'Ocorreu um erro ao carregar o chat: ${e.toString()}'};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Center(child: Text("Faça login para ver suas mensagens."));
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _chatData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Erro: ${snapshot.error}')));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(
              child: Text('Não foi possível carregar os dados do chat.'));
        }

        final data = snapshot.data!;
        if (data.containsKey('error')) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(data['error'])));
        }

        // Se chegou aqui, os dados estão ok para abrir o chat
        // (Assume que TelaChat existe e recebe esses parâmetros)
        // return TelaChat(
        //   chatId: data['chatId']!,
        //   nomeReceptor: data['nomeReceptor']!,
        // );
         return Center(child: Text("Tela de Chat para ${data['nomeReceptor']} (ID: ${data['chatId']})")); // Placeholder
      },
    );
  }
}

