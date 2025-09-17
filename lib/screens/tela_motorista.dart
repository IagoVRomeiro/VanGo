import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Certifique-se de que o caminho para sua tela de perfil está correto
// import 'package:interface_app2/screens/tela_perfil.dart';

// --- Tela de Perfil de Exemplo (caso você não a tenha) ---
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Esta é a tela de perfil.'),
      ),
    );
  }
}
// -----------------------------------------------------------


class MotoristaHomeScreen extends StatefulWidget {
  // CORREÇÃO: Construtor atualizado para usar super parameters.
  const MotoristaHomeScreen({super.key});

  @override
  State<MotoristaHomeScreen> createState() => _MotoristaHomeScreenState();
}

class _MotoristaHomeScreenState extends State<MotoristaHomeScreen> {
  late GoogleMapController mapController;
  // Posição inicial (ex: centro de Belo Horizonte)
  final LatLng _initialPosition = const LatLng(-19.9245, -43.9352); 

  // Conjunto de marcadores para o mapa
  final Set<Marker> _markers = {};

  int _selectedIndex = 0; // Para controlar o item selecionado na BottomNavigationBar

  @override
  void initState() {
    super.initState();
    _addMarkers(); // Adiciona alguns marcadores de exemplo
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _addMarkers() {
    // Adicione alguns marcadores de exemplo no mapa
    
    // CORREÇÃO: Removido 'const' antes de Marker, pois BitmapDescriptor é um método.
    _markers.add(
      Marker(
        markerId: const MarkerId('currentLocation'),
        position: _initialPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Sua Localização'),
      ),
    );

    // Marcadores adicionais
    _markers.add(
      Marker( // 'const' removido
        markerId: const MarkerId('marker1'),
        position: const LatLng(-19.9200, -43.9400),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );
    _markers.add(
      Marker( // 'const' removido
        markerId: const MarkerId('marker2'),
        position: const LatLng(-19.9300, -43.9300),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );
    _markers.add(
      Marker( // 'const' removido
        markerId: const MarkerId('marker3'),
        position: const LatLng(-19.9150, -43.9250),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );
     _markers.add(
      Marker( // 'const' removido
        markerId: const MarkerId('marker4'),
        position: const LatLng(-19.9350, -43.9450),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );
    _markers.add(
      Marker( // 'const' removido
        markerId: const MarkerId('marker5'),
        position: const LatLng(-19.9100, -43.9300),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );
    _markers.add(
      Marker( // 'const' removido
        markerId: const MarkerId('marker6'),
        position: const LatLng(-19.9280, -43.9180),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );
     _markers.add(
      Marker( // 'const' removido
        markerId: const MarkerId('marker7'),
        position: const LatLng(-19.9050, -43.9400),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );
    _markers.add(
      Marker( // 'const' removido
        markerId: const MarkerId('marker8'),
        position: const LatLng(-19.9400, -43.9350),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );
  }

  void _onItemTapped(int index) {
    // Se o usuário clicar no mesmo item, não faz nada
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });
    
    if (index == 2) { // Índice 2 é o perfil
      // Navega para a tela de perfil e reseta o índice ao voltar
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PerfilScreen()),
      ).then((_) {
        // Quando o usuário voltar da tela de perfil, o mapa será selecionado de novo
        setState(() {
          _selectedIndex = 0;
        });
      });
    }
    // TODO: Adicionar navegação para a tela de Chat (índice 1) se ela existir
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // TODO: Implementar ação para o menu (ex: abrir Drawer)
            debugPrint('Menu pressionado');
          },
        ),
        // CORREÇÃO: Adicionado 'const' para melhorar performance.
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MOTORISTA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              'Olá, João Silva',
              style: TextStyle(
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              // TODO: Implementar ação para notificações
              debugPrint('Notificações pressionadas');
            },
          ),
        ],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _initialPosition,
          zoom: 12.0,
        ),
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implementar ação para o botão de adicionar (ex: registrar nova rota)
          debugPrint('Botão de adicionar pressionado');
        },
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
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
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}