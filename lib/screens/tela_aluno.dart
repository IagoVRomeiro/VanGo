// lib/screens/tela_aluno.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vango/models/aluno.dart';
import 'package:vango/models/motorista.dart';
import 'package:vango/screens/tela_busca_motorista.dart';
import 'package:vango/screens/tela_chat.dart';
import 'package:vango/widgets/acao_flutuante_item.dart';
import 'package:vango/widgets/botao_acao_animado.dart';

class AlunoHomeScreen extends StatefulWidget {
  const AlunoHomeScreen({super.key});

  @override
  State<AlunoHomeScreen> createState() => _AlunoHomeScreenState();
}

class _AlunoHomeScreenState extends State<AlunoHomeScreen> {
  late GoogleMapController mapController;
  final LatLng _initialPosition = const LatLng(-19.9245, -43.9352);
  final Set<Marker> _markers = {};
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _addMarkers();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _addMarkers() {
    _markers.add(
      Marker(
        markerId: const MarkerId('school'),
        position: _initialPosition,
        infoWindow: const InfoWindow(title: 'Escola / Local do Aluno'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    );
  }

  final List<AcaoFlutuanteItem> _itensAluno = [
    const AcaoFlutuanteItem(valor: 'procurar_motorista', texto: 'Procurar motorista', icone: Icons.search),
  ];

  void _onAcaoSelecionada(String valor) {
    if (valor == 'procurar_motorista') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaBuscaMotorista()));
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const AlunoPerfilScreen()));
    } else {
      if (_selectedIndex == index) return;
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget mapaWidget = Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 14.0),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        ),
        if (_selectedIndex == 0)
          Positioned(
            bottom: 16,
            right: 60,
            child: BotaoAcaoAnimado(
              itens: _itensAluno,
              onAcaoSelecionada: _onAcaoSelecionada,
              corDoBotao: Colors.amber,
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_selectedIndex == 0 ? 'Mapa do Aluno' : 'Chat com Motorista'),
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
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

class AlunoChatWrapper extends StatefulWidget {
  const AlunoChatWrapper({super.key});

  @override
  State<AlunoChatWrapper> createState() => _AlunoChatWrapperState();
}

class _AlunoChatWrapperState extends State<AlunoChatWrapper> {
  Future<Map<String, String>>? _chatData;

  @override
  void initState() {
    super.initState();
    _chatData = _getChatData();
  }

  Future<Map<String, String>> _getChatData() async {
    final alunoId = FirebaseAuth.instance.currentUser!.uid;
    final alunoDoc = await FirebaseFirestore.instance.collection('alunos').doc(alunoId).get();
    if (!alunoDoc.exists) throw Exception('Perfil do aluno não encontrado.');

    final aluno = Aluno.fromMap(alunoDoc.data()!);
    final motoristaId = aluno.motoristaId;
    if (motoristaId.isEmpty) throw Exception('Aluno não vinculado a um motorista.');

    final motoristaDoc = await FirebaseFirestore.instance.collection('motoristas').doc(motoristaId).get();
    if (!motoristaDoc.exists) throw Exception('Motorista não encontrado.');
    final motorista = Motorista.fromMap(motoristaDoc.data()!);

    final ids = [motoristaId, alunoId]..sort();
    final chatId = ids.join('_');

    return {'chatId': chatId, 'nomeReceptor': motorista.nome};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _chatData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Erro ao carregar chat: ${snapshot.error}')));
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('Não foi possível carregar os dados do chat.'));
        }

        final data = snapshot.data!;
        return TelaChat(
          chatId: data['chatId']!,
          nomeReceptor: data['nomeReceptor']!,
        );
      },
    );
  }
}

class AlunoPerfilScreen extends StatelessWidget {
  const AlunoPerfilScreen({super.key});
  @override
  Widget build(BuildContext context) { 
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do Aluno'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Esta é a tela de perfil do aluno.'),
      ),
    );
  }
}