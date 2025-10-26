import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Imports relativos
import 'tela_cadastro.dart';
import 'tela_lista_chats.dart';
import 'tela_perfil.dart';
import 'tela_viagem.dart';
import 'tela_gerenciar_alunos.dart';
// 🔹 ADICIONADO: Import da tela de notificações
import 'tela_notificacoes.dart';

class TelaMotorista extends StatefulWidget {
  // 🔹 CORRIGIDO: Removido 'const'
   TelaMotorista({super.key});

  @override
  State<TelaMotorista> createState() => _TelaMotoristaState();
}

class _TelaMotoristaState extends State<TelaMotorista> {
  late GoogleMapController mapController;
  final LatLng _initialPosition = const LatLng(-19.9245, -43.9352);
  final Set<Marker> _markers = {};
  final List<LatLng> _alunos = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _addMarker(_initialPosition, "Sua Localização");
  }

  void _addMarker(LatLng position, String title) {
    _markers.add(
      Marker(
        markerId: MarkerId(title),
        position: position,
        infoWindow: InfoWindow(title: title),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro ao sair: $e")));
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _onItemTapped(int index) {
    final user = FirebaseAuth.instance.currentUser;
    // Checa 'Viagem'(1), 'Alunos'(2), 'Chat'(3) ou 'Perfil'(4)
    if (user == null && (index >= 1 && index <= 4)) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const TelaCadastro()));
      return;
    }

    // Navega para Perfil (índice 4)
    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PerfilScreen(collectionPath: 'motoristas'),
        ),
      );
    } else { // Muda a aba
      if (_selectedIndex == index) return;
      setState(() => _selectedIndex = index);
    }
  }

  void _adicionarAluno(LatLng position) {
    setState(() {
      _alunos.add(position);
      _addMarker(position, "Aluno ${_alunos.length}");
    });
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0: return 'Mapa do Motorista';
      case 1: return 'Gerenciar Viagem';
      case 2: return 'Gerenciar Alunos';
      case 3: return 'Minhas Conversas';
      default: return _getAppBarTitle(_selectedIndex); // Caso 4 (Perfil) navega
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
              CameraPosition(target: _initialPosition, zoom: 12.0),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          onTap: (pos) => _adicionarAluno(pos),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(_selectedIndex)),
        backgroundColor: const Color(0xFFE53935),
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
        // 🔹 ADICIONADO: Botão de notificações
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notificações',
            onPressed: () {
              Navigator.push(
                context,
                // 🔹 CORRIGIDO: Removido 'const'
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
          const TelaViagem(), // Índice 1
          const TelaGerenciarAlunos(), // Índice 2
          const TelaListaChats(), // Índice 3
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Essencial para 5+ itens
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'), // 0
          BottomNavigationBarItem(icon: Icon(Icons.edit_road_outlined), label: 'Viagem'), // 1
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), label: 'Alunos'), // 2
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'), // 3
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'), // 4
        ],
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

