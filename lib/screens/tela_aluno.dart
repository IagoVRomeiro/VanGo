import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/rota.dart';
import 'tela_perfil.dart';
import 'tela_notificacoes.dart';
import 'tela_login.dart';
import 'tela_lista_chats.dart';
import 'tela_busca_motorista.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bottom_nav_bar.dart';
import '../widgets/neon_drawer.dart';


class TelaAluno extends StatefulWidget {
  TelaAluno({super.key});

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

    if (index == 2) {
      await _navigateToBuscaMotorista();
    } else if (index == 3) {
      await _navigateToPerfil();
    } else {
      if (_selectedIndex == index) return;
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _handlePerfilNavResult(dynamic result) {
    if (result is! PerfilNavResult || result.isDriver) return;

    switch (result.targetIndex) {
      case 0:
      case 1:
        if (_selectedIndex != result.targetIndex) {
          setState(() {
            _selectedIndex = result.targetIndex;
          });
        }
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TelaBuscaMotorista(),
          ),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _navigateToPerfil() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PerfilScreen(
          collectionPath: 'alunos',
          showAppBar: true,
        ),
      ),
    );
    _handlePerfilNavResult(result);
  }

  Future<void> _navigateToBuscaMotorista() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TelaBuscaMotorista(),
      ),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TelaNotificacoes()),
    );
  }

  List<NeonDrawerItem> _buildDrawerItems(BuildContext context) {
    return [
      NeonDrawerItem(
        icon: Icons.map,
        label: 'Mapa',
        onTap: () async {
          if (!mounted) return;
          if (_selectedIndex != 0) {
            setState(() => _selectedIndex = 0);
          }
        },
      ),
      NeonDrawerItem(
        icon: Icons.chat,
        label: 'Conversas',
        onTap: () async {
          if (!mounted) return;
          if (_selectedIndex != 1) {
            setState(() => _selectedIndex = 1);
          }
        },
      ),
      NeonDrawerItem(
        icon: Icons.search,
        label: 'Buscar Motorista',
        onTap: () async {
          await _navigateToBuscaMotorista();
        },
      ),
      NeonDrawerItem(
        icon: Icons.person,
        label: 'Meu Perfil',
        onTap: () async {
          await _navigateToPerfil();
        },
      ),
    ];
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
            )
          : null,
      drawer: isLoggedIn
          ? NeonDrawer(
              items: _buildDrawerItems(context),
              onSettings: _navigateToPerfil,
              onLogout: _logout,
            )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          mapaWidget, // Índice 0
          const TelaListaChats(), // Índice 1
          // As telas de busca e perfil serão navegadas diretamente
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
