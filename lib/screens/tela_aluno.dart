import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vango/models/rota.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/screens/tela_configuracoes.dart';
import 'package:vango/l10n/app_localizations.dart';
import 'tela_perfil.dart';
import 'tela_notificacoes.dart';
import 'tela_lista_chats.dart';
import 'tela_busca_motorista.dart';
import 'tela_selecao.dart';
import 'tela_login.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bottom_nav_bar.dart';
import '../widgets/neon_drawer.dart';
import '../widgets/notifications_bell.dart';


class TelaAluno extends StatefulWidget {
  final int initialIndex;
  const TelaAluno({super.key, this.initialIndex = 0});

  @override
  State<TelaAluno> createState() => _TelaAlunoState();
}

class _TelaAlunoState extends State<TelaAluno> {
  GoogleMapController? _mapController;
  final LatLng _initialPosition = const LatLng(-19.9245, -43.9352);
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  int _selectedIndex = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _rotaSubscription;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
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
          MaterialPageRoute(builder: (_) => const TelaSelecao()),
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

  void _onItemTapped(int index) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TelaLogin()),
      );
      return;
    }

    if (index == 3) {
      await _navigateToPerfil();
      return;
    }

    if (index == 1 || index == 2) {
      final enderecoValido = await _validarEnderecoPreenchido();
      if (!enderecoValido) {
        return;
      }
    }

    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _navigateToPerfil() async {
    if (_selectedIndex == 3) return;
    setState(() {
      _selectedIndex = 3;
    });
  }

  Future<void> _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TelaConfiguracoes()),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TelaNotificacoes()),
    );
  }

  String _getAppBarTitle(int index) {
    final l10n = AppLocalizations.of(context)!;
    switch (index) {
      case 0:
        return l10n.alunoMapTitle;
      case 1:
        return l10n.chatMotoristaTitle;
      case 2:
        return l10n.procurarMotoristaTitle; 
      case 3:
        return l10n.meuPerfilTitle;
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
        _limparRota();
        return;
      }

      final data = snapshot.docs.first.data();
      final status = data['status'] as String?;
      final polyline = data['polylineRota'];

      if (status != StatusRota.emAndamento.name || polyline == null) {
        _removerMarcadorMotorista();
        _limparRota();
        return;
      }

      final geo = data['localizacaoAtualMotorista'];
      _renderizarRotaAluno(data);
      if (geo is GeoPoint) {
        _atualizarMarcadorMotorista(
          LatLng(geo.latitude, geo.longitude),
        );
      } else {
        _removerMarcadorMotorista();
      }
    });
  }

  void _renderizarRotaAluno(Map<String, dynamic> data) {
    final List<dynamic>? polylineRaw = data['polylineRota'] as List<dynamic>?;
    final List<dynamic>? paradasRaw = data['paradasOrdenadas'] as List<dynamic>?;
    final destinoRaw = data['destino'];

    final parsedPolyline = polylineRaw
            ?.map(_parseLatLng)
            .where((p) => p != null)
            .cast<LatLng>()
            .toList() ??
        [];
    final paradas = paradasRaw
            ?.map(_parseLatLng)
            .where((p) => p != null)
            .cast<LatLng>()
            .toList() ??
        [];
    final destino = _parseLatLng(destinoRaw);

    setState(() {
      _polylines.clear();
      if (parsedPolyline.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('rota_motorista'),
            color: Colors.blueAccent,
            width: 6,
            points: parsedPolyline,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }

      _markers.removeWhere((m) =>
          m.markerId.value == 'destino' || m.markerId.value.startsWith('parada_'));

      for (var i = 0; i < paradas.length; i++) {
        _markers.add(
          Marker(
            markerId: MarkerId('parada_$i'),
            position: paradas[i],
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: 'Parada ${i + 1}'),
          ),
        );
      }

      if (destino != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destino'),
            position: destino,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'Destino'),
          ),
        );
      }
    });
    _ajustarCameraParaRota(parsedPolyline, paradas, destino);
  }

  LatLng? _parseLatLng(dynamic value) {
    if (value is GeoPoint) {
      return LatLng(value.latitude, value.longitude);
    }
    if (value is Map<String, dynamic>) {
      final lat = value['lat'];
      final lng = value['lng'];
      if (lat is num && lng is num) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  void _ajustarCameraParaRota(
    List<LatLng> polylinePoints,
    List<LatLng> paradas,
    LatLng? destino,
  ) {
    if (_mapController == null) return;

    final pontos = <LatLng>[];
    pontos.addAll(polylinePoints);
    pontos.addAll(paradas);
    if (destino != null) {
      pontos.add(destino);
    }
    final motoristaMarker =
        _markers.where((m) => m.markerId.value == 'motorista_atual').toList();
    if (motoristaMarker.isNotEmpty) {
      pontos.add(motoristaMarker.first.position);
    }

    if (pontos.isEmpty) return;

    double minLat = pontos.first.latitude;
    double maxLat = pontos.first.latitude;
    double minLng = pontos.first.longitude;
    double maxLng = pontos.first.longitude;

    for (final p in pontos.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    if (minLat == maxLat && minLng == maxLng) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(pontos.first, 15),
      );
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60),
    );
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

  void _limparRota() {
    setState(() {
      _polylines.clear();
      _markers.removeWhere((m) =>
          m.markerId.value == 'destino' || m.markerId.value.startsWith('parada_'));
    });
  }

  Future<bool> _validarEnderecoPreenchido() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final endereco = doc.data()?['endereco'];
      final preenchido =
          endereco is String && endereco.trim().isNotEmpty;
      if (!preenchido) {
        await _mostrarDialogoEnderecoObrigatorio();
      }
      return preenchido;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível validar seu endereço: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _mostrarDialogoEnderecoObrigatorio() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Endereço obrigatório'),
          content: const Text(
              'Para conversar com motoristas ou procurá-los, informe seu endereço no perfil.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Agora não'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _navigateToPerfil();
              },
              child: const Text('Ir para Perfil'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isLoggedIn = userId.isNotEmpty;

    Widget mapaWidget = Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition:
              CameraPosition(target: _initialPosition, zoom: 14.0),
          markers: _markers,
          polylines: _polylines,
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
              notificationAction: NotificationsBell(
                role: UserRole.aluno,
                userId: userId,
                onPressed: _openNotifications,
              ),
            )
          : null,
      drawer: isLoggedIn
          ? NeonDrawer(
              onSettings: _navigateToSettings,
              onLogout: _logout,
            )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          mapaWidget, // Índice 0
          const TelaListaChats(showAppBar: false), // Índice 1
          TelaBuscaMotorista(showScaffold: false), // Índice 2
          const PerfilScreen(collectionPath: 'alunos', showAppBar: false), // Índice 3
        ],
      ),
      bottomNavigationBar: NeonBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.map), label: AppLocalizations.of(context)!.navMap),
          BottomNavigationBarItem(icon: const Icon(Icons.chat), label: AppLocalizations.of(context)!.navChat),
          BottomNavigationBarItem(icon: const Icon(Icons.search), label: AppLocalizations.of(context)!.navSearch),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: AppLocalizations.of(context)!.navProfile),
        ],
        selectedColor: Theme.of(context).colorScheme.primary,
        unselectedColor: Colors.white70,
      ),
    );
  }
}
