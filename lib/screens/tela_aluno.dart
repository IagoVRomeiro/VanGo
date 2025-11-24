import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tela_perfil.dart';
import 'tela_notificacoes.dart';
import 'tela_login.dart';
import 'tela_lista_chats.dart';
import 'tela_busca_motorista.dart';


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
          builder: (context) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: Colors.yellow,
                    onPrimary: Colors.black,
                  ),
            ),
            child: const TelaBuscaMotorista(),
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
            showAppBar: true,
            themeColor: Colors.yellow,
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

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Colors.yellow, // Cor primária amarela para alunos
              onPrimary: Colors.black, // Texto/ícones pretos para contraste
            ),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.yellow, // Fundo amarelo
          foregroundColor: Colors.black, // Ícones e texto pretos
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
              icon: const Icon(Icons.notifications),
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
            mapaWidget, // Índice 0
            const TelaListaChats(), // Índice 1
            // As telas de busca e perfil serão navegadas diretamente
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
          selectedItemColor: Colors.black, // Ícones selecionados em preto
          unselectedItemColor: Colors.grey, // Ícones não selecionados em cinza
        ),
      ),
    );
  }
}

// Removido AlunoChatWrapper
