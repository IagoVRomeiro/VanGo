import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vango/config/api_keys.dart';
import 'package:vango/models/rota.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/screens/tela_configuracoes.dart';
import 'package:vango/l10n/app_localizations.dart';
import 'package:vango/services/distance_matrix_service.dart';
import 'tela_perfil.dart';
import 'tela_convites.dart';
import 'tela_lista_chats.dart';
import 'tela_busca_motorista.dart';
import 'tela_selecao.dart';
import 'tela_login.dart';
import 'tela_historico_viagens.dart';
import 'tela_notificacoes.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bottom_nav_bar.dart';
import '../widgets/neon_drawer.dart';
import '../widgets/notifications_bell.dart';
import '../widgets/messages_badge.dart';


class TelaAluno extends StatefulWidget {
  final int initialIndex;
  const TelaAluno({super.key, this.initialIndex = 0});

  @override
  State<TelaAluno> createState() => _TelaAlunoState();
}

class _TelaAlunoState extends State<TelaAluno> {
  static const int _etaMinIntervalSeconds = 45;
  static const double _etaOriginMoveMeters = 120;
  static const double _etaDestinationMoveMeters = 40;
  static const double _chegandoThresholdMeters = 200;

  GoogleMapController? _mapController;
  final LatLng _initialPosition = const LatLng(-19.9245, -43.9352);
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  int _selectedIndex = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _rotaSubscription;
  GeoPoint? _alunoGeo;
  LatLng? _motoristaLatLng;
  double? _motoristaDistanceMeters;
  DateTime? _ultimaAtualizacaoMotorista;
  String? _rotaNome;
  bool _rotaEmAndamento = false;
  bool _carregandoLocalizacaoAluno = false;
  DistanceMatrixService? _distanceMatrixService;
  String? _etaText;
  DateTime? _lastEtaFetchAt;
  LatLng? _lastEtaOrigin;
  LatLng? _lastEtaDestination;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _distanceMatrixService = DistanceMatrixService(apiKey: googleApiKey);
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
      MaterialPageRoute(builder: (context) => TelaConvites()),
    );
  }

  Future<void> _openHistorico() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TelaHistoricoViagens.aluno(),
      ),
    );
  }

  Future<void> _openNotificacoesClima() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TelaNotificacoes(),
      ),
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
        _limparStatusMotorista();
        return;
      }

      final data = snapshot.docs.first.data();
      final status = data['status'] as String?;
      final polyline = data['polylineRota'];

      if (status != StatusRota.emAndamento.name || polyline == null) {
        _removerMarcadorMotorista();
        _limparRota();
        _limparStatusMotorista();
        return;
      }

      final geo = data['localizacaoAtualMotorista'];
      _renderizarRotaAluno(data);
      if (geo is GeoPoint) {
        final driverLatLng = LatLng(geo.latitude, geo.longitude);
        _atualizarMarcadorMotorista(driverLatLng);
        _atualizarStatusMotorista(data, driverLatLng);
      } else {
        _removerMarcadorMotorista();
        _atualizarStatusMotorista(data, null);
      }
    });
  }

  Future<void> _carregarLocalizacaoAluno() async {
    if (_carregandoLocalizacaoAluno) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _carregandoLocalizacaoAluno = true;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('alunos').doc(user.uid).get();
      final geo = doc.data()?['localizacao'] as GeoPoint?;
      if (!mounted) return;
      setState(() {
        _alunoGeo = geo;
      });
      _recalcularDistanciaMotorista();
      if (_motoristaLatLng != null) {
        _atualizarEtaMotorista(_motoristaLatLng!);
      }
    } catch (_) {
      // Silencia falhas, status de distância é opcional.
    } finally {
      _carregandoLocalizacaoAluno = false;
    }
  }

  void _recalcularDistanciaMotorista() {
    if (_alunoGeo == null || _motoristaLatLng == null) return;
    final distance = Geolocator.distanceBetween(
      _alunoGeo!.latitude,
      _alunoGeo!.longitude,
      _motoristaLatLng!.latitude,
      _motoristaLatLng!.longitude,
    );
    if (!mounted) return;
    setState(() {
      _motoristaDistanceMeters = distance;
    });
  }

  void _limparStatusMotorista() {
    if (!mounted) return;
    setState(() {
      _rotaEmAndamento = false;
      _rotaNome = null;
      _motoristaLatLng = null;
      _motoristaDistanceMeters = null;
      _ultimaAtualizacaoMotorista = null;
      _etaText = null;
      _lastEtaFetchAt = null;
      _lastEtaOrigin = null;
      _lastEtaDestination = null;
    });
  }

  void _atualizarStatusMotorista(Map<String, dynamic> data, LatLng? driverLatLng) {
    if (_alunoGeo == null) {
      _carregarLocalizacaoAluno();
    }
    final lastUpdate = data['ultimaAtualizacaoMotorista'] as Timestamp?;
    final rotaNome = data['nome'] as String?;
    double? distance;
    if (_alunoGeo != null && driverLatLng != null) {
      distance = Geolocator.distanceBetween(
        _alunoGeo!.latitude,
        _alunoGeo!.longitude,
        driverLatLng.latitude,
        driverLatLng.longitude,
      );
    }
    final chegando = distance != null && distance <= _chegandoThresholdMeters;
    if (!mounted) return;
    setState(() {
      _rotaEmAndamento = true;
      _rotaNome = rotaNome;
      _motoristaLatLng = driverLatLng;
      _ultimaAtualizacaoMotorista = lastUpdate?.toDate();
      _motoristaDistanceMeters = distance;
      if (chegando) {
        _etaText = null;
      }
    });

    if (!chegando && driverLatLng != null && _distanceMatrixService != null) {
      _atualizarEtaMotorista(driverLatLng);
    }
  }

  bool _shouldFetchEta(LatLng origin, LatLng destination) {
    final lastFetch = _lastEtaFetchAt;
    if (lastFetch == null) return true;
    final elapsed = DateTime.now().difference(lastFetch);
    if (elapsed.inSeconds >= _etaMinIntervalSeconds) return true;
    if (_lastEtaOrigin == null || _lastEtaDestination == null) return true;
    final movedOrigin = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      _lastEtaOrigin!.latitude,
      _lastEtaOrigin!.longitude,
    );
    final movedDestination = Geolocator.distanceBetween(
      destination.latitude,
      destination.longitude,
      _lastEtaDestination!.latitude,
      _lastEtaDestination!.longitude,
    );
    return movedOrigin >= _etaOriginMoveMeters ||
        movedDestination >= _etaDestinationMoveMeters;
  }

  Future<void> _atualizarEtaMotorista(LatLng driverLatLng) async {
    final alunoGeo = _alunoGeo;
    final service = _distanceMatrixService;
    if (alunoGeo == null || service == null) return;

    final destination = LatLng(alunoGeo.latitude, alunoGeo.longitude);
    if (!_shouldFetchEta(driverLatLng, destination)) return;

    _lastEtaFetchAt = DateTime.now();
    _lastEtaOrigin = driverLatLng;
    _lastEtaDestination = destination;

    final metrics =
        await service.fetchDriveMetrics(origin: driverLatLng, destination: destination);
    if (!mounted) return;

    final seconds = metrics?.durationInTrafficSeconds ?? metrics?.durationSeconds;
    setState(() {
      _etaText = _formatDurationSeconds(seconds);
    });
  }

  String? _formatDurationSeconds(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) return '${hours}h';
    return '${hours}h ${remaining}m';
  }

  String? _formatUpdatedAt(DateTime? timestamp) {
    if (timestamp == null) return null;
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 45) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    return 'há ${diff.inDays} d';
  }

  String _formatDistance(num meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  Widget _buildStatusMotorista(ThemeData theme) {
    if (!_rotaEmAndamento) return const SizedBox.shrink();
    final distanceText = _motoristaDistanceMeters == null
        ? null
        : _formatDistance(_motoristaDistanceMeters!);
    final chegando = _motoristaDistanceMeters != null &&
        _motoristaDistanceMeters! <= _chegandoThresholdMeters;
    final updatedText = _formatUpdatedAt(_ultimaAtualizacaoMotorista);
    final statusParts = <String>[
      if (chegando) 'chegando',
      if (!chegando && _etaText != null) 'ETA $_etaText',
      if (!chegando && distanceText != null) 'a $distanceText de você',
      if (updatedText != null) updatedText,
    ];
    final statusText = statusParts.join(' • ');
    final title = _rotaNome == null || _rotaNome!.trim().isEmpty
        ? 'Motorista em rota'
        : _rotaNome!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_bus,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (statusText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      statusText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
        Positioned(
          left: 16,
          right: 16,
          top: 16,
          child: _buildStatusMotorista(Theme.of(context)),
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
              onNotifications: _openNotificacoesClima,
              onHistory: _openHistorico,
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
          BottomNavigationBarItem(
            icon: MessagesBadge(userId: userId, icon: Icons.chat),
            label: AppLocalizations.of(context)!.navChat,
          ),
          BottomNavigationBarItem(icon: const Icon(Icons.search), label: AppLocalizations.of(context)!.navSearch),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: AppLocalizations.of(context)!.navProfile),
        ],
        selectedColor: Theme.of(context).colorScheme.primary,
        unselectedColor: Colors.white70,
      ),
    );
  }
}
