// lib/screens/tela_motorista.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vango/models/directions_info.dart';
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
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bottom_nav_bar.dart';
import '../widgets/neon_drawer.dart';

class TelaMotorista extends StatefulWidget {
  final int initialIndex;
  final String? rotaParaExibirId;

  const TelaMotorista(
      {super.key, this.initialIndex = 0, this.rotaParaExibirId});

  @override
  State<TelaMotorista> createState() => _TelaMotoristaState();
}

class _RouteStatusChip extends StatelessWidget {
  const _RouteStatusChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.95),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Calculando rota...',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteSummaryPanel extends StatelessWidget {
  final DirectionsInfo? directionsInfo;
  final List<String> stops;

  const _RouteSummaryPanel({
    required this.directionsInfo,
    required this.stops,
  });

  @override
  Widget build(BuildContext context) {
    final info = directionsInfo;
    if (info == null || stops.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.95),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trajeto Planejado',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (info.totalDistance != null) info.totalDistance!,
                if (info.totalDuration != null) info.totalDuration!,
              ].join(' • '),
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: stops.length,
                itemBuilder: (context, index) {
                  final label = index == stops.length - 1 ? 'Destino' : 'Parada ${index + 1}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.8),
                          child: Text(
                            index == stops.length - 1 ? 'D' : '${index + 1}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                stops[index],
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  DirectionsInfo? _directionsInfo;
  final List<String> _rotaSequenciaParadas = [];
  bool _calculandoRota = false;

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
        Geolocator.getPositionStream().listen((Position position) async {
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
      if (_rotaEmAndamentoId != null) {
        try {
          await FirebaseFirestore.instance
              .collection('rotas')
              .doc(_rotaEmAndamentoId)
              .update({
            'localizacaoAtualMotorista':
                GeoPoint(position.latitude, position.longitude),
            'ultimaAtualizacaoMotorista': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint(
              'Erro ao atualizar localização do motorista na rota: $e');
        }
      }
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

  GeoPoint? _parseGeoPoint(dynamic value) {
    if (value is GeoPoint) {
      return value;
    }
    if (value is Map<String, dynamic>) {
      final lat = value['latitude'] ?? value['lat'];
      final lng = value['longitude'] ?? value['lng'];
      if (lat is num && lng is num) {
        return GeoPoint(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  Future<List<QueryDocumentSnapshot>> _fetchAlunosInBatches(
      List<String> alunosIds) async {
    if (alunosIds.isEmpty) {
      return [];
    }

    final List<QueryDocumentSnapshot> allAlunos = [];
    final firestore = FirebaseFirestore.instance;

    for (var i = 0; i < alunosIds.length; i += 10) {
      final sublist =
          alunosIds.sublist(i, i + 10 > alunosIds.length ? alunosIds.length : i + 10);
      final snapshot = await firestore
          .collection('alunos')
          .where(FieldPath.documentId, whereIn: sublist)
          .get();
      allAlunos.addAll(snapshot.docs);
    }
    return allAlunos;
  }

  Future<void> _exibirRota(String rotaId) async {
    try {
      if (mounted) {
        setState(() {
          _calculandoRota = true;
          _directionsInfo = null;
          _rotaSequenciaParadas.clear();
        });
      }
      final directionsService = DirectionsService(apiKey: _apiKey);
      final rotaDoc = await FirebaseFirestore.instance.collection('rotas').doc(rotaId).get();
      if (!rotaDoc.exists) {
        if (mounted) setState(() => _calculandoRota = false);
        return;
      }
      if (!mounted) return;

      final rota = Rota.fromSnapshot(rotaDoc);
      final alunosIds = rota.listaAlunosIds;

      if (alunosIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Esta rota não tem alunos.")),
        );
        return;
      }

      final alunosDocs = await _fetchAlunosInBatches(alunosIds);
      final alunosComLocalizacao = <MapEntry<GeoPoint, String>>[];
      for (final doc in alunosDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final geoPoint = _parseGeoPoint(data['localizacao']);
        if (geoPoint == null) {
          continue;
        }
        final nome = (data['nome'] as String?)?.trim();
        alunosComLocalizacao.add(
          MapEntry(geoPoint, nome?.isNotEmpty == true ? nome! : 'Aluno sem nome'),
        );
      }

      if (alunosComLocalizacao.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Nenhum aluno desta rota possui localização cadastrada."),
            ),
          );
          setState(() => _calculandoRota = false);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final motoristaLocation = LatLng(position.latitude, position.longitude);

      final destinoFinal = LatLng(rota.localDestino.latitude, rota.localDestino.longitude);

      final List<LatLng> waypoints = alunosComLocalizacao
          .map((entry) => LatLng(entry.key.latitude, entry.key.longitude))
          .toList();

      final directionsInfo = await directionsService.getDirections(
        origin: motoristaLocation,
        destination: destinoFinal,
        waypoints: waypoints,
      );

      if (directionsInfo == null) {
        if (mounted) {
          setState(() => _calculandoRota = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Não foi possível calcular a rota no momento."),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final orderedStops = directionsInfo.waypointOrder
          ?.map((index) => alunosComLocalizacao[index])
          .toList() ?? [];

      _markers.clear();
      for (final entry in orderedStops) {
        _addMarker(
          LatLng(entry.key.latitude, entry.key.longitude),
          entry.value,
          "Parada do Aluno",
          BitmapDescriptor.hueGreen,
        );
      }

      _addMarker(destinoFinal, "Destino Final", rota.nome, BitmapDescriptor.hueRed);

      setState(() {
        _rotaAtual = rota;
        _directionsInfo = directionsInfo;
        _rotaSequenciaParadas
          ..clear()
          ..addAll(orderedStops.map((entry) => entry.value))
          ..add(rota.localDestinoNome);
        _polylines.clear();
        if (directionsInfo.polylinePoints.isNotEmpty) {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('rota_coleta'),
              color: Colors.blue,
              width: 5,
              points: directionsInfo.polylinePoints,
            ),
          );
        }
        _calculandoRota = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _calculandoRota = false);
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
      _directionsInfo = null;
      _rotaSequenciaParadas.clear();
      _carregarAlunosNoMapa();
    });
  }

  Future<void> _carregarAlunosNoMapa() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (mounted) {
        setState(() => _calculandoRota = false);
      }
      final motoristaDoc = await FirebaseFirestore.instance.collection('motoristas').doc(user.uid).get();
      final motoristaData = motoristaDoc.data();
      final alunosIds = List<String>.from(motoristaData?['alunosIds'] ?? []);

      if (alunosIds.isEmpty) return;
      
      final alunosDocs = await _fetchAlunosInBatches(alunosIds);

      for (var doc in alunosDocs) {
        final alunoData = doc.data() as Map<String, dynamic>;
        final localizacao = _parseGeoPoint(alunoData['localizacao']);
        if (localizacao == null) {
          continue;
        }
        final nome = (alunoData['nome'] as String?)?.trim();
        _addMarker(
          LatLng(localizacao.latitude, localizacao.longitude),
          nome?.isNotEmpty == true ? nome! : 'Aluno',
          "",
          BitmapDescriptor.hueGreen,
        );
      }
      if (mounted) {
        setState(() {
          _directionsInfo = null;
          _rotaSequenciaParadas.clear();
        });
      }
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

  void _onItemTapped(int index) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaLogin()));
      return;
    }

    if (index == 4) {
      await _navigateToPerfil();
      return;
    } else {
      if (_selectedIndex == index) return;
      setState(() => _selectedIndex = index);
    }
  }

  Future<void> _navigateToPerfil() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PerfilScreen(
          collectionPath: 'motoristas',
          showAppBar: true,
          themeColor: Colors.red,
        ),
      ),
    );
    _handlePerfilNavResult(result);
  }

  void _handlePerfilNavResult(dynamic result) {
    if (result is! PerfilNavResult || !result.isDriver) return;
    final target = result.targetIndex;

    if (target >= 0 && target <= 3 && _selectedIndex != target) {
      setState(() => _selectedIndex = target);
    }
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
    final bool isLoggedIn = user != null;

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
        if (_calculandoRota)
          const Positioned(
            top: 16,
            right: 16,
            child: _RouteStatusChip(),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _RouteSummaryPanel(
            directionsInfo: _directionsInfo,
            stops: _rotaSequenciaParadas,
          ),
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
              title: 'Menu do Motorista',
              onSettings: _navigateToPerfil,
              onLogout: _logout,
            )
          : null,
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
          isLoggedIn ? const TelaViagem() : _buildLoginPromptWidget(context),
          isLoggedIn
              ? const TelaGerenciarAlunos(showAppBar: false)
              : _buildLoginPromptWidget(context),
          isLoggedIn ? const TelaListaChats() : _buildLoginPromptWidget(context),
          _buildLoginPromptWidget(context),
        ],
      ),
      bottomNavigationBar: NeonBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.edit_road_outlined), label: 'Viagem'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), label: 'Alunos'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        selectedColor: Theme.of(context).colorScheme.primary,
        unselectedColor: Colors.white70,
      ),
    );
  }
}
