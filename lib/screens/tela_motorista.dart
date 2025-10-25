import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Imports relativos
import 'tela_cadastro.dart';
import 'tela_lista_chats.dart';
import 'tela_perfil.dart';
import 'tela_viagem.dart';
// 🔹 ADICIONADO: Import da nova tela
import 'tela_gerenciar_alunos.dart';
// 🔹 ADICIONADO: Import da tela de notificações
import 'tela_notificacoes.dart';

class TelaMotorista extends StatefulWidget {
  const TelaMotorista({super.key});

  @override
  State<TelaMotorista> createState() => _TelaMotoristaState();
}

class _TelaMotoristaState extends State<TelaMotorista> {
  late GoogleMapController mapController;
  final LatLng _initialPosition = const LatLng(-19.9245, -43.9352);
  final Set<Marker> _markers = {};
  final List<LatLng> _alunos = []; // Lista de alunos para rotas
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
    // 🔹 ATUALIZADO: Checa 'Viagem' (1), 'Alunos' (2), 'Chat' (3) ou 'Perfil' (4)
    if (user == null && (index == 1 || index == 2 || index == 3 || index == 4)) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const TelaCadastro()));
      return;
    }

    // 🔹 ATUALIZADO: 'Perfil' agora é o índice 4
    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PerfilScreen(collectionPath: 'motoristas'),
        ),
      );
    } else {
      // Itens 0, 1, 2 e 3 apenas mudam o estado
      if (_selectedIndex == index) return;
      setState(() => _selectedIndex = index);
    }
  }

  void _adicionarAluno(LatLng position) {
    // Lógica para adicionar aluno ao mapa (exemplo)
    setState(() {
      _alunos.add(position);
      _addMarker(position, "Aluno ${_alunos.length}");
    });
  }

  // 🔹 ATUALIZADO: Helper para definir o título do AppBar
  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Mapa do Motorista';
      case 1:
        return 'Gerenciar Viagem';
      // 🔹 ADICIONADO
      case 2:
        return 'Gerenciar Alunos';
      // 🔹 ATUALIZADO
      case 3:
        return 'Minhas Conversas';
      default:
        // Se o índice for 4 (Perfil), ele navega, então o título não muda
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
              CameraPosition(target: _initialPosition, zoom: 12.0),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          onTap: (pos) => _adicionarAluno(pos), // toque no mapa para adicionar aluno
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
        // 🔹 ADICIONADO: Botão de Notificações
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notificações',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TelaNotificacoes(),
                ),
              );
            },
          ),
        ],
      ),
      // 🔹 ATUALIZADO: IndexedStack agora tem 4 filhos
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          mapaWidget, // Índice 0
          const TelaViagem(), // Índice 1
          const TelaGerenciarAlunos(), // Índice 2 (NOVO)
          const TelaListaChats(), // Índice 3
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        // 'fixed' é essencial para 5 itens
        type: BottomNavigationBarType.fixed,
        // 🔹 ATUALIZADO: Agora com 5 itens
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'), // 0
          BottomNavigationBarItem(
              icon: Icon(Icons.edit_road_outlined), label: 'Viagem'), // 1
          // 🔹 ADICIONADO: Nova aba "Alunos"
          BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_outlined), label: 'Alunos'), // 2
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'), // 3
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'), // 4
        ],
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

