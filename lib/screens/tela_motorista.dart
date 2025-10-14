// lib/screens/tela_motorista.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vango/screens/tela_cadastro.dart';
import 'package:vango/screens/tela_criarRota.dart';
import 'package:vango/screens/tela_criarVan.dart';
import 'package:vango/screens/tela_lista_chats.dart';
// ✅ CORREÇÃO: IMPORTS DOS WIDGETS ADICIONADOS
import 'package:vango/widgets/acao_flutuante_item.dart';
import 'package:vango/widgets/botao_acao_animado.dart';


class TelaMotorista extends StatefulWidget {
  const TelaMotorista({super.key});

  @override
  State<TelaMotorista> createState() => _TelaMotoristaState();
}

class _TelaMotoristaState extends State<TelaMotorista> {
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
        markerId: const MarkerId('currentLocation'),
        position: _initialPosition,
        infoWindow: const InfoWindow(title: 'Sua Localização'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
  }

  final List<AcaoFlutuanteItem> _itensMotorista = [
    const AcaoFlutuanteItem(valor: 'criar_rota', texto: 'Criar rota', icone: Icons.route_outlined),
    const AcaoFlutuanteItem(valor: 'cadastrar_van', texto: 'Cadastrar van', icone: Icons.airport_shuttle_outlined),
  ];

  void _onAcaoSelecionada(String valor) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TelaCadastro()),
      );
      return;
    }

    if (valor == 'criar_rota') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const CriarRotaScreen()));
    } else if (valor == 'cadastrar_van') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const CadastrarVanScreen()));
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaCadastro()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const PerfilScreen()));
      }
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
          initialCameraPosition: CameraPosition(
            target: _initialPosition,
            zoom: 12.0,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        ),
        if (_selectedIndex == 0)
          Positioned(
            bottom: 16,
            right: 60,
            child: BotaoAcaoAnimado(
              itens: _itensMotorista,
              onAcaoSelecionada: _onAcaoSelecionada,
              corDoBotao: const Color(0xFFE53935),
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Mapa do Motorista' : 'Minhas Conversas'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          mapaWidget,
          TelaListaChats(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do Motorista'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('Esta é a tela de perfil do motorista.')),
    );
  }
}