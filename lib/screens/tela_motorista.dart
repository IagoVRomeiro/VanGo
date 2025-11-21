// lib/screens/tela_motorista.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vango/models/rota.dart';
import 'package:vango/services/directions_service.dart';
import 'package:vango/services/permission_service.dart';

// Imports relativos
import 'tela_cadastro.dart';
import 'tela_gerenciar_alunos.dart';
import 'tela_lista_chats.dart';
import 'tela_login.dart';
import 'tela_notificacoes.dart';
import 'tela_perfil.dart';
import 'tela_viagem.dart';

class TelaMotorista extends StatefulWidget {
  final int initialIndex;
  final String? rotaParaExibirId;

  const TelaMotorista(
      {super.key, this.initialIndex = 0, this.rotaParaExibirId});

  @override
  State<TelaMotorista> createState() => _TelaMotoristaState();
}

class _TelaMotoristaState extends State<TelaMotorista> {
  late GoogleMapController mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  late int _selectedIndex;
  String _apiKey = "";

  // State for Trip Mode
  String? _rotaEmAndamentoId;
  Rota? _rotaAtual;
  bool _emModoViagemFinal = false;

  // State for Live Location
  final PermissionService _permissionService = PermissionService();
  StreamSubscription<Position>? _positionStreamSubscription;
  Marker? _driverMarker;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadApiKeyAndData();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _loadApiKeyAndData() async {
    _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'CHAVE_NAO_ENCONTRADA';

    final hasPermission = await _permissionService.handleLocationPermission();
    if (hasPermission) {
      _startLocationUpdates();
      if (widget.rotaParaExibirId != null) {
        _selectedIndex = 0;
        _rotaEmAndamentoId = widget.rotaParaExibirId;
        await _exibirRota(widget.rotaParaExibirId!);
      } else {
        _carregarAlunosNoMapa();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Permissão de localização é necessária para usar o mapa.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _startLocationUpdates() {
    _positionStreamSubscription =
        Geolocator.getPositionStream().listen((Position position) {
      final driverLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _driverMarker = Marker(
          markerId: const MarkerId('driver'),
          position: driverLatLng,
          infoWindow: const InfoWindow(title: 'Sua Posição'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        );
        _markers.removeWhere((m) => m.markerId.value == 'driver');
        _markers.add(_driverMarker!);
      });

      mapController.animateCamera(CameraUpdate.newLatLng(driverLatLng));
    });
  }

  void _addMarker(
      LatLng position, String title, String snippet, double hue) {
    if (title == 'Sua Posição') return;

    _markers.add(
      Marker(
        markerId: MarkerId(title),
        position: position,
        infoWindow: InfoWindow(title: title, snippet: snippet),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      ),
    );
  }

  Future<void> _exibirRota(String rotaId) async {
    try {
      final directionsService = DirectionsService(apiKey: _apiKey);
      final rotaDoc = await FirebaseFirestore.instance.collection('rotas').doc(rotaId).get();
      if (!rotaDoc.exists || !mounted) return;

      final rota = Rota.fromSnapshot(rotaDoc);
      final alunosIds = rota.listaAlunosIds;

      if (alunosIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Esta rota não tem alunos.")),
        );
        return;
      }

      final alunosSnapshot = await FirebaseFirestore.instance
          .collection('alunos')
          .where(FieldPath.documentId, whereIn: alunosIds)
          .get();

      final position = await Geolocator.getCurrentPosition();
      final motoristaLocation = LatLng(position.latitude, position.longitude);

      final List<LatLng> waypoints = alunosSnapshot.docs.map((doc) {
        final loc = doc.data()['localizacao'] as GeoPoint;
        return LatLng(loc.latitude, loc.longitude);
      }).toList();

      _markers.clear();
      for (var doc in alunosSnapshot.docs) {
        final loc = doc.data()['localizacao'] as GeoPoint;
        _addMarker(LatLng(loc.latitude, loc.longitude), doc.data()['nome'], "Parada do Aluno", BitmapDescriptor.hueGreen);
      }
      
      final LatLng destinoFinal = LatLng((rota.localDestino as GeoPoint).latitude, (rota.localDestino as GeoPoint).longitude);
      _addMarker(destinoFinal, "Destino Final", rota.nome, BitmapDescriptor.hueRed);

      final directionsInfo = await directionsService.getDirections(
        origin: motoristaLocation,
        destination: motoristaLocation,
        waypoints: waypoints,
      );

      setState(() {
        _rotaAtual = rota;
        if (directionsInfo != null && directionsInfo.polylinePoints.isNotEmpty) {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('rota_coleta'),
              color: Colors.blue,
              width: 5,
              points: directionsInfo.polylinePoints,
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Erro ao exibir rota: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _iniciarRotaFinal() async {
    if (_rotaAtual == null) return;
    
    final directionsService = DirectionsService(apiKey: _apiKey);
    final position = await Geolocator.getCurrentPosition();
    final motoristaLocation = LatLng(position.latitude, position.longitude);

    final LatLng destinoFinal = LatLng(
      (_rotaAtual!.localDestino as GeoPoint).latitude,
      (_rotaAtual!.localDestino as GeoPoint).longitude);

    final directionsInfo = await directionsService.getDirections(
      origin: motoristaLocation,
      destination: destinoFinal,
    );

    setState(() {
      _polylines.clear();
      if (directionsInfo != null && directionsInfo.polylinePoints.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('rota_final'),
            color: Colors.purple,
            width: 5,
            points: directionsInfo.polylinePoints,
          ),
        );
      }
       _emModoViagemFinal = true;
    });
  }

  Future<void> _finalizarViagem() async {
    if (_rotaAtual == null) return;
    
    await FirebaseFirestore.instance.collection('rotas').doc(_rotaAtual!.id).update({
      'status': StatusRota.concluida.name
    });

    setState(() {
      _polylines.clear();
      _markers.clear();
      _rotaEmAndamentoId = null;
      _rotaAtual = null;
      _emModoViagemFinal = false;
      _carregarAlunosNoMapa();
    });
  }

  Future<void> _carregarAlunosNoMapa() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final motoristaDoc = await FirebaseFirestore.instance.collection('motoristas').doc(user.uid).get();
      final motoristaData = motoristaDoc.data();
      final alunosIds = List<String>.from(motoristaData?['alunosIds'] ?? []);

      if (alunosIds.isEmpty) return;
      
      final alunosSnapshot = await FirebaseFirestore.instance
          .collection('alunos')
          .where(FieldPath.documentId, whereIn: alunosIds)
          .get();

      for (var doc in alunosSnapshot.docs) {
        final alunoData = doc.data();
        final nome = alunoData['nome'] as String?;
        final localizacao = alunoData['localizacao'] as GeoPoint?;

        if (nome != null && localizacao != null) {
          _addMarker(
            LatLng(localizacao.latitude, localizacao.longitude),
            nome,
            "",
            BitmapDescriptor.hueGreen,
          );
        }
      }
      if(mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Erro ao carregar alunos no mapa: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao sair: $e")));
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _onItemTapped(int index) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null && (index >= 1 && index <= 3)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaLogin()));
      return;
    }

    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PerfilScreen(
            collectionPath: 'motoristas',
            showAppBar: false,
          ),
        ),
      );
      return;
    } else {
      if (_selectedIndex == index) return;
      setState(() => _selectedIndex = index);
    }
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
        return 'Meu Perfil';
      default:
        setState(() => _selectedIndex = 0);
        return 'Mapa do Motorista';
    }
  }

  Widget _buildLoginPromptWidget(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 90, color: theme.colorScheme.onSurface.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text(
              'Funcionalidade Exclusiva para Motoristas',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Faça login ou crie uma conta para gerenciar suas viagens e alunos.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
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
    final motoristaTheme = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Colors.red,
            onPrimary: Colors.white,
          ),
    );

    Widget mapaWidget = Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: const CameraPosition(
              target: LatLng(-19.9245, -43.9352), zoom: 12.0),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        ),
      ],
    );

    return Theme(
      data: motoristaTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getAppBarTitle(_selectedIndex)),
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
        floatingActionButton: _rotaEmAndamentoId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _emModoViagemFinal ? _finalizarViagem : _iniciarRotaFinal,
                label: Text(_emModoViagemFinal ? 'Finalizar Viagem' : 'Ir para o Destino Final'),
                icon: Icon(_emModoViagemFinal ? Icons.done_all : Icons.flag),
              ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            mapaWidget,
            user != null ? const TelaViagem() : _buildLoginPromptWidget(context),
            user != null ? const TelaGerenciarAlunos() : _buildLoginPromptWidget(context),
            user != null ? const TelaListaChats() : _buildLoginPromptWidget(context),
            _buildLoginPromptWidget(context),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
            BottomNavigationBarItem(icon: Icon(Icons.edit_road_outlined), label: 'Viagem'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), label: 'Alunos'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}
