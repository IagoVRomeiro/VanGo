import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapaMotoristaScreen extends StatefulWidget {
  const MapaMotoristaScreen({super.key});

  @override
  State<MapaMotoristaScreen> createState() => _MapaMotoristaScreenState();
}

class _MapaMotoristaScreenState extends State<MapaMotoristaScreen> {
  // Controller to interact with the map.
  late GoogleMapController mapController;

  // Default initial camera position (centered on Belo Horizonte, MG).
  final LatLng _initialPosition = const LatLng(-19.9245, -43.9352);

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // This function is called when the '+' button is pressed.
  void _mostrarOpcoesDeRota() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Opções de Rota'),
          content: ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: const Text('Registrar Nova Rota'),
            onTap: () {
              // First, close the dialog.
              Navigator.of(context).pop();
              // Then, navigate to the route registration screen.
              // For now, it just prints a message.
              print('Navegar para a tela de registro de rota!');
              // TODO: Criar e navegar para a tela de cadastro de rota.
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
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
        backgroundColor: const Color(0xFF333333), // Using the driver theme color
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _initialPosition,
          zoom: 12.0,
        ),
        myLocationEnabled: true, // Shows the blue dot for the user's location
        myLocationButtonEnabled: true, // Adds a button to center the map on the user
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarOpcoesDeRota,
        tooltip: 'Adicionar Rota',
        backgroundColor: const Color(0xFF333333), // Matching the driver theme
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
