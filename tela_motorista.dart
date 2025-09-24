import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vango/screens/tela_cadastro.dart';

class MotoristaHomeScreen extends StatefulWidget {
  const MotoristaHomeScreen({super.key});

  @override
  State<MotoristaHomeScreen> createState() => _MotoristaHomeScreenState();
}

class _MotoristaHomeScreenState extends State<MotoristaHomeScreen> {
  late GoogleMapController mapController;

  // Centro de BH
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

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    if (index == 2) {
      // Navega para a tela de perfil
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PerfilScreen(),
        ),
      ).then((_) {
        setState(() {
          _selectedIndex = 0;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Motorista',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'Bem vindo à tela do Motorista',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
      ),
      body: Stack(
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
          Positioned(
            bottom: 16,
            right: 60,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CadastroScreen()),
                );
              },
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add, size: 30),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// Tela de perfil do motorista
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
      body: const Center(
        child: Text('Esta é a tela de perfil do motorista.'),
      ),
    );
  }
}
