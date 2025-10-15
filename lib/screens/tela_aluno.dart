// lib/screens/tela_aluno.dart (VERSÃO CORRIGIDA)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Imports relativos
import '../models/aluno.dart';
import '../models/motorista.dart';
import 'tela_busca_motorista.dart';
import 'tela_chat.dart';
import 'tela_perfil.dart';
import 'tela_cadastro.dart';
import '../widgets/acao_flutuante_item.dart';
import '../widgets/botao_acao_animado.dart';

class TelaAluno extends StatefulWidget {
  const TelaAluno({super.key});

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

  // ✅✅✅ PASSO 1: Adicionar a função de logout ✅✅✅
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        // Navega para a tela inicial (seleção) e remove todas as outras.
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
        infoWindow: const InfoWindow(title: 'Escola / Local do Aluno'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    );
  }

  final List<AcaoFlutuanteItem> _itensAluno = [
    const AcaoFlutuanteItem(
        valor: 'procurar_motorista',
        texto: 'Procurar motorista',
        icone: Icons.search),
  ];

  void _onAcaoSelecionada(String valor) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => const TelaCadastro()));
      return;
    }

    if (valor == 'procurar_motorista') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const TelaBuscaMotorista()));
    }
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

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PerfilScreen(collectionPath: 'alunos'),
        ),
      );
    } else {
      if (_selectedIndex == index) return;
      setState(() {
        _selectedIndex = index;
      });
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
        
        // ✅✅✅ PASSO 2: Lógica do botão implementada ✅✅✅
        // Se o usuário estiver logado, mostra o botão de deslogar.
        // Se não, mostra o botão de voltar.
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
        title: Text(
            _selectedIndex == 0 ? 'Mapa do Aluno' : 'Chat com Motorista'),
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

// O widget AlunoChatWrapper não precisa de alterações.
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
      final alunoDoc = await FirebaseFirestore.instance.collection('alunos').doc(alunoId).get();
      if (!alunoDoc.exists) throw Exception('Perfil do aluno não encontrado.');

      final aluno = Aluno.fromMap(alunoDoc.id, alunoDoc.data()!);
      final motoristaId = aluno.motoristaId;

      if (motoristaId.isEmpty) {
        return {'error': 'Você ainda não está vinculado a um motorista.'};
      }

      final motoristaDoc = await FirebaseFirestore.instance.collection('motoristas').doc(motoristaId).get();
      if (!motoristaDoc.exists) throw Exception('Motorista não encontrado.');
      final motorista = Motorista.fromMap(motoristaDoc.id, motoristaDoc.data()!);

      final ids = [motoristaId, alunoId]..sort();
      final chatId = ids.join('_');

      return {'chatId': chatId, 'nomeReceptor': motorista.nome};
    } catch (e) {
      return {'error': 'Ocorreu um erro: ${e.toString()}'};
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

        return TelaChat(
          chatId: data['chatId']!,
          nomeReceptor: data['nomeReceptor']!,
        );
      },
    );
  }
}