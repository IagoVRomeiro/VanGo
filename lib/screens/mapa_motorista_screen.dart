import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:interface_app2/screens/perfil_screen.dart'; // Para navegar para o perfil

class MapaMotoristaScreen extends StatefulWidget {
  const MapaMotoristaScreen({super.key});

  @override
  State<MapaMotoristaScreen> createState() => _MapaMotoristaScreenState();
}

class _MapaMotoristaScreenState extends State<MapaMotoristaScreen> {
  late GoogleMapController mapController;
  final LatLng _initialPosition = const LatLng(-19.9245, -43.9352); // Posição inicial

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _mostrarOpcoesDeRota() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Opções de Rota'),
          content: ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: const Text('Registar Nova Rota'),
            onTap: () {
              Navigator.of(context).pop();
              // TODO: Navegar para a tela de registo de rota.
              debugPrint('Navegar para a tela de registo de rota!');
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Rotas'),
        backgroundColor: const Color(0xFF333333),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PerfilScreen()),
              );
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
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarOpcoesDeRota,
        tooltip: 'Adicionar Rota',
        backgroundColor: const Color(0xFF333333),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

