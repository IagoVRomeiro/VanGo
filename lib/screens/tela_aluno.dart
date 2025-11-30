import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vango/models/rota.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/screens/tela_configuracoes.dart';
import 'tela_perfil.dart';
import 'tela_notificacoes.dart';
import 'tela_lista_chats.dart';
import 'tela_busca_motorista.dart';
import 'tela_selecao.dart';
import 'tela_login.dart'; // Adicionar esta linha
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bottom_nav_bar.dart';
import '../widgets/neon_drawer.dart';
import '../widgets/notifications_bell.dart';


class TelaAluno extends StatefulWidget {
  final int initialIndex;
  TelaAluno({super.key, this.initialIndex = 0});

  @override
  State<TelaAluno> createState() => _TelaAlunoState();
}

class _TelaAlunoState extends State<TelaAluno> {
  GoogleMapController? _mapController;
  final LatLng _initialPosition = const LatLng(-19.9245, -43.9352);
  final Set<Marker> _markers = {};
  int _selectedIndex = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _rotaSubscription;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _addMarkers();
    _ouvirLocalizacaoDoMotorista();
  }

  @override
  void dispose() {
    _rotaSubscription?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await _rotaSubscription?.cancel();
      _rotaSubscription = null;
      _removerMarcadorMotorista();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TelaSelecao()),
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
    _mapController = controller;
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

  void _onItemTapped(int index) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TelaLogin()),
      );
      return;
    }

    if (index == 3) {
      await _navigateToPerfil();
      return;
    }

    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _navigateToPerfil() async {
    if (_selectedIndex == 3) return;
    setState(() {
      _selectedIndex = 3;
    });
  }

  Future<void> _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TelaConfiguracoes()),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TelaNotificacoes()),
    );
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

  void _ouvirLocalizacaoDoMotorista() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _rotaSubscription = FirebaseFirestore.instance
        .collection('rotas')
        .where('listaAlunosIds', arrayContains: user.uid)
        .where('status', isEqualTo: StatusRota.emAndamento.name)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.docs.isEmpty) {
        _removerMarcadorMotorista();
        return;
      }

      final data = snapshot.docs.first.data();
      final geo = data['localizacaoAtualMotorista'];
      if (geo is GeoPoint) {
        _atualizarMarcadorMotorista(
          LatLng(geo.latitude, geo.longitude),
        );
      } else {
        _removerMarcadorMotorista();
      }
    });
  }

  void _atualizarMarcadorMotorista(LatLng position) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'motorista_atual');
      _markers.add(
        Marker(
          markerId: const MarkerId('motorista_atual'),
          position: position,
          infoWindow: const InfoWindow(title: 'Seu motorista'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  void _removerMarcadorMotorista() {
    final exists = _markers.any((m) => m.markerId.value == 'motorista_atual');
    if (!exists) return;
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'motorista_atual');
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isLoggedIn = user != null;

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
      appBar: isLoggedIn
          ? NeonAppBar(
              title: _getAppBarTitle(_selectedIndex),
              onNotificationsPressed: _openNotifications,
              notificationAction: NotificationsBell(
                role: UserRole.aluno,
                userId: user!.uid,
                onPressed: _openNotifications,
              ),
            )
          : null,
      drawer: isLoggedIn
          ? NeonDrawer(
              onSettings: _navigateToSettings,
              onLogout: _logout,
            )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          mapaWidget, // Índice 0
          const TelaListaChats(showAppBar: false), // Índice 1
          TelaBuscaMotorista(showScaffold: false), // Índice 2
          const PerfilScreen(collectionPath: 'alunos', showAppBar: false), // Índice 3
        ],
      ),
      bottomNavigationBar: NeonBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Procurar'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        selectedColor: Theme.of(context).colorScheme.primary,
        unselectedColor: Colors.white70,
      ),
    );
  }
}

// Removido AlunoChatWrapper

// Removido AlunoChatWrapper
