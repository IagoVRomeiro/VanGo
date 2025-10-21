import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Imports relativos
import 'tela_cadastro.dart';
import 'tela_criarRota.dart';
import 'tela_criarVan.dart';
import 'tela_lista_chats.dart';
import 'tela_perfil.dart';
import '../widgets/acao_flutuante_item.dart';
import '../widgets/botao_acao_animado.dart';

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
  bool _isMenuAberto = false;

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

  final List<AcaoFlutuanteItem> _itensMotorista = [
    const AcaoFlutuanteItem(
        valor: 'criar_rota', texto: 'Criar rota', icone: Icons.route_outlined),
    const AcaoFlutuanteItem(
        valor: 'cadastrar_van',
        texto: 'Cadastrar van',
        icone: Icons.airport_shuttle_outlined),
  ];

  void _onAcaoSelecionada(String valor) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const TelaCadastro()));
      return;
    }

   // dentro de tela_motorista.dart
if (valor == 'criar_rota') {
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const CriarRotaScreen(), // <-- REMOVA O PARÂMETRO
      ));
}else if (valor == 'cadastrar_van') {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CadastrarVanScreen()));
    }

    setState(() => _isMenuAberto = false);
  }

  void _onItemTapped(int index) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null && (index == 1 || index == 2)) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const TelaCadastro()));
      return;
    }

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const PerfilScreen(collectionPath: 'motoristas'),
        ),
      );
    } else {
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
        Positioned(
          bottom: 16,
          right: 20,
          child: BotaoAcaoAnimado(
            itens: _itensMotorista,
            onAcaoSelecionada: _onAcaoSelecionada,
            corDoBotao: const Color(0xFFE53935),
            onMenuToggle: () => setState(() => _isMenuAberto = !_isMenuAberto),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? 'Mapa do Motorista' : 'Minhas Conversas',
        ),
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
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          mapaWidget,
          const TelaListaChats(),
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
