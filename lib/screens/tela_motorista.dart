// lib/screens/tela_motorista.dart

// 🔹 CORREÇÃO: Imports corrigidos
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Imports relativos
import 'tela_login.dart';
import 'tela_cadastro.dart'; // Import necessário para o prompt
import 'tela_lista_chats.dart';
import 'tela_perfil.dart';
import 'tela_viagem.dart';
import 'tela_gerenciar_alunos.dart';
import 'tela_notificacoes.dart';

class TelaMotorista extends StatefulWidget {
  // 🔹 1. ADICIONE O PARÂMETRO
  final int initialIndex;

  // 🔹 2. ATUALIZE O CONSTRUTOR
  const TelaMotorista({super.key, this.initialIndex = 0});

  @override
  State<TelaMotorista> createState() => _TelaMotoristaState();
}

class _TelaMotoristaState extends State<TelaMotorista> {
  late GoogleMapController mapController;
  final LatLng _initialPosition = const LatLng(-19.9245, -43.9352);
  final Set<Marker> _markers = {};
  final List<LatLng> _alunos = [];
  
  // 🔹 3. MUDE COMO O ÍNDICE É DECLARADO
  late int _selectedIndex; // Remova a inicialização (= 0) daqui

  @override
  void initState() {
    super.initState();
    
    // 🔹 4. DEFINA O ÍNDICE A PARTIR DO WIDGET
    _selectedIndex = widget.initialIndex; // Define o índice recebido
    
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
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TelaLogin()),
          (route) => false,
        );
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
    // Checa se está deslogado e tenta acessar abas protegidas
    if (user == null && (index >= 1 && index <= 3)) { // 🔹 Corrigido: índice 3 é o último protegido
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const TelaLogin()));
      return;
    }

    // Navega para Perfil (índice 4)
    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PerfilScreen(
            collectionPath: 'motoristas',
          ),
        ),
      );
      return; // Importante retornar aqui
    } else {
      // Muda a aba se não for o Perfil
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

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Mapa do Motorista';
      case 1:
        return 'Gerenciar Viagem';
      case 2:
        return 'Gerenciar Alunos';
      case 3:
        return 'Minhas Conversas';
      case 4:
        return 'Meu Perfil'; // Título antes de navegar
      default:
        setState(() => _selectedIndex = 0); // Corrige índice inválido
        return 'Mapa do Motorista';
    }
  }

  // 🔹 Widget de placeholder para convidados
  Widget _buildLoginPromptWidget(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 90, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Funcionalidade Exclusiva para Motoristas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Faça login ou crie uma conta para gerenciar suas viagens e alunos.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TelaLogin()),
                );
              },
              child: const Text('Fazer Login'),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TelaCadastro()),
                );
              },
              child: const Text('Não tenho uma conta (Criar)'),
            )
          ],
        ),
      ),
    );
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
          onTap: (pos) => _adicionarAluno(pos),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
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
      // 🔹 BODY ATUALIZADO (para proteger abas no modo convidado)
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          mapaWidget, // Índice 0
          
          // Índice 1 (Protegido)
          user != null ? const TelaViagem() : _buildLoginPromptWidget(context), 
          
          // Índice 2 (Protegido)
          user != null ? const TelaGerenciarAlunos() : _buildLoginPromptWidget(context), 
          
          // Índice 3 (Protegido)
          user != null ? const TelaListaChats() : _buildLoginPromptWidget(context),
          
          // Índice 4 (Perfil) é tratado por _onItemTapped, 
          // mas adicionamos um placeholder caso o índice seja 4 por engano
          _buildLoginPromptWidget(context),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'), // 0
          BottomNavigationBarItem(
              icon: Icon(Icons.edit_road_outlined), label: 'Viagem'), // 1
          BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_outlined), label: 'Alunos'), // 2
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'), // 3
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Perfil'), // 4
        ],
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}