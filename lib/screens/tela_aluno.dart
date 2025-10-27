import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/aluno.dart';
import '../models/motorista.dart';
import 'tela_chat.dart';
import 'tela_perfil.dart';
import 'tela_cadastro.dart';
import 'tela_notificacoes.dart';
import 'tela_login.dart';


class TelaAluno extends StatefulWidget {
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
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TelaLogin()),
          (route) => false,
        );
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

    if (user == null && (index == 1 || index == 2 || index == 3)) { 
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TelaLogin()),
      );
      return;
    }

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Procurar Motorista'),
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Text('Aqui ficará a lista de motoristas para procurar.'),
            ),
          ),
        ),
      );
     
    }
    else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PerfilScreen(
            collectionPath: 'alunos',
          ),
        ),
      );
    }

    else {
      if (_selectedIndex == index) return;
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Mapa do Aluno';
      case 1:
        return 'Chat com Motorista';
      case 2:
        return 'Procurar Motorista'; 
      case 3:
        return 'Meu Perfil';
      default:
        return _getAppBarTitle(_selectedIndex);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notificações',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TelaNotificacoes()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          mapaWidget, 
          const AlunoChatWrapper(), 

        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, 
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'), 
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'), 
          BottomNavigationBarItem( 
              icon: Icon(Icons.search), label: 'Procurar'), 
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Perfil'), 
        ],
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

// ... (AlunoChatWrapper)
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
      final alunoDoc =
          await FirebaseFirestore.instance.collection('alunos').doc(alunoId).get();
      if (!alunoDoc.exists) throw Exception('Perfil do aluno não encontrado.');

      final motoristaId = alunoDoc.data()?['motoristaId'] as String?;

      if (motoristaId == null || motoristaId.isEmpty) {
        return {'error': 'Você ainda não está vinculado a um motorista.'};
      }

      final motoristaDoc = await FirebaseFirestore.instance
          .collection('motoristas')
          .doc(motoristaId)
          .get();
      if (!motoristaDoc.exists) throw Exception('Motorista não encontrado.');
      final nomeMotorista = motoristaDoc.data()?['nome'] ?? 'Motorista';

      final ids = [motoristaId, alunoId]..sort();
      final chatId = ids.join('_');

      return {'chatId': chatId, 'nomeReceptor': nomeMotorista};
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
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(
              child: Text('Não foi possível carregar os dados do chat.'));
        }

        final data = snapshot.data!;
        if (data.containsKey('error')) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(data['error'] as String)));
        }

        return Center(
            child: Text(
                "Tela de Chat para ${data['nomeReceptor']} (ID: ${data['chatId']})")); // Placeholder
      },
    );
  }
}
