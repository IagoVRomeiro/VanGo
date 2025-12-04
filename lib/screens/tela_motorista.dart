import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vango/models/directions_info.dart';
import 'package:vango/models/rota.dart';
import 'package:vango/services/directions_service.dart';
import 'package:vango/services/local_cache.dart';
import 'package:vango/services/permission_service.dart';
import 'package:vango/l10n/app_localizations.dart';
import '../models/usuario.dart';
import 'package:vango/screens/tela_configuracoes.dart';
import 'tela_cadastro.dart';
import 'tela_gerenciar_alunos.dart';
import 'tela_lista_chats.dart';
import 'tela_login.dart';
import 'tela_selecao.dart';
import 'tela_notificacoes.dart';
import 'tela_perfil.dart';
import 'tela_viagem.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bottom_nav_bar.dart';
import '../widgets/neon_drawer.dart';
import '../widgets/notifications_bell.dart';

class TelaMotorista extends StatefulWidget {
  final int initialIndex;
  final String? rotaParaExibirId;

  const TelaMotorista(
      {super.key, this.initialIndex = 0, this.rotaParaExibirId});

  @override
  State<TelaMotorista> createState() => _TelaMotoristaState();
}

class _AlunosBatchResult {
  final List<DocumentSnapshot<Map<String, dynamic>>> docs;
  final bool hadPermissionErrors;

  const _AlunosBatchResult(this.docs, this.hadPermissionErrors);
}

class _AlunoDisplayInfo {
  final String id;
  final String nome;
  final String? fotoUrl;
  final GeoPoint geoPoint;

  const _AlunoDisplayInfo({
    required this.id,
    required this.nome,
    required this.geoPoint,
    this.fotoUrl,
  });
}

class _AlunoMarkerData {
  final String id;
  final String nome;
  final String? fotoUrl;

  const _AlunoMarkerData({
    required this.id,
    required this.nome,
    this.fotoUrl,
  });
}

class _RouteStatusChip extends StatelessWidget {
  const _RouteStatusChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
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
  final bool isExpanded;
  final VoidCallback onToggle;

  const _RouteSummaryPanel({
    required this.directionsInfo,
    required this.stops,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final info = directionsInfo;
    if (info == null || stops.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      if (info.totalDistance != null) info.totalDistance!,
                      if (info.totalDuration != null) info.totalDuration!,
                    ].join(' • '),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: onToggle,
                ),
              ],
            ),
            if (isExpanded) ...[
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
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.8),
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
          ],
        ),
      ),
    );
  }
}

class _TelaMotoristaState extends State<TelaMotorista> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Map<String, _AlunoMarkerData> _alunoMarkersData = {};
  late int _selectedIndex;
  String _apiKey = "";

  // State for Trip Mode
  String? _rotaEmAndamentoId;
  Rota? _rotaAtual;
  DirectionsInfo? _directionsInfo;
  final List<String> _rotaSequenciaParadas = [];
  bool _calculandoRota = false;
  bool _mostrarResumoRota = true;

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
    _mapController?.dispose();
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

      if (_directionsInfo != null) {
        _animateCameraToNavigation(driverLatLng, _directionsInfo!.polylinePoints);
      } else {
        _mapController?.animateCamera(CameraUpdate.newLatLng(driverLatLng));
      }
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
      LatLng position, String title, String snippet, double hue,
      {String? markerId,
      String? alunoNome,
      String? alunoFotoUrl,
      String? alunoId}) {
    if (title == 'Sua Posição') return;

    final id = markerId ?? title;
    if (alunoNome != null || alunoFotoUrl != null || alunoId != null) {
      _alunoMarkersData[id] = _AlunoMarkerData(
        id: alunoId ?? id,
        nome: alunoNome ?? title,
        fotoUrl: alunoFotoUrl,
      );
    }

    _markers.add(
      Marker(
        markerId: MarkerId(id),
        position: position,
        infoWindow: InfoWindow(title: title, snippet: snippet),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        onTap: () => _onAlunoMarkerTap(id),
      ),
    );
  }

  void _onAlunoMarkerTap(String markerId) {
    final data = _alunoMarkersData[markerId];
    if (data == null || !mounted) return;

    Future<List<String>> rotasDoAluno() async {
      final motoristaId = FirebaseAuth.instance.currentUser?.uid;
      if (motoristaId == null) return [];
      final snapshot = await FirebaseFirestore.instance
          .collection('rotas')
          .where('motoristaId', isEqualTo: motoristaId)
          .where('listaAlunosIds', arrayContains: data.id)
          .limit(5)
          .get();
      return snapshot.docs
          .map((doc) =>
              (doc.data()['nome'] as String?)?.trim().isNotEmpty == true
                  ? (doc.data()['nome'] as String)
                  : 'Rota sem nome')
          .toList();
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage:
                      data.fotoUrl != null && data.fotoUrl!.isNotEmpty ? NetworkImage(data.fotoUrl!) : null,
                  child: (data.fotoUrl == null || data.fotoUrl!.isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.nome,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      FutureBuilder<List<String>>(
                        future: rotasDoAluno(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Text(AppLocalizations.of(context)!.loadingRoutes);
                          }
                          final rotas = snapshot.data ?? [];
                          if (rotas.isEmpty) {
                            return Text(AppLocalizations.of(context)!.noRoutesLinked);
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: rotas
                                .map((rotaNome) => Text(
                                      AppLocalizations.of(context)!.routeLabel(rotaNome),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addStyledPolyline(String id, List<LatLng> points, Color color) {
    if (points.isEmpty) return;
    _polylines.add(
      Polyline(
        polylineId: PolylineId('${id}_background'),
        color: color.withValues(alpha: 0.25),
        width: 14,
        points: points,
        zIndex: 1,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );
    _polylines.add(
      Polyline(
        polylineId: PolylineId(id),
        color: color,
        width: 7,
        points: points,
        zIndex: 2,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
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

  LatLng? _parseLatLng(dynamic value) {
    final geo = _parseGeoPoint(value);
    if (geo != null) return LatLng(geo.latitude, geo.longitude);
    if (value is Map<String, dynamic>) {
      final lat = value['lat'];
      final lng = value['lng'];
      if (lat is num && lng is num) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  Future<Map<String, Usuario?>> _fetchUsuarios(List<String> ids) async {
    final futures = ids.map((id) async {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(id).get();
      return MapEntry(id, snap.exists ? Usuario.fromSnapshot(snap) : null);
    });
    final entries = await Future.wait(futures);
    return Map<String, Usuario?>.fromEntries(entries);
  }

  Future<List<_AlunoDisplayInfo>> _fetchAlunosComUsuario(
      List<String> alunosIds) async {
    final alunosResult = await _fetchAlunosInBatches(alunosIds);
    if (mounted && alunosResult.hadPermissionErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alguns passageiros não puderam ser carregados. Verifique se estão vinculados ao motorista.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    final alunosDocs = alunosResult.docs;
    final usuarios = await _fetchUsuarios(alunosIds);

    final alunosComDados = <_AlunoDisplayInfo>[];
    for (final doc in alunosDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final geoPoint = _parseGeoPoint(data['localizacao']);
      if (geoPoint == null) {
        continue;
      }
      final usuario = usuarios[doc.id];
      final usuarioNome = (usuario?.nome ?? '').trim();
      final nomeAluno = (usuarioNome.isNotEmpty)
          ? usuarioNome
          : ((data['nome'] as String?)?.trim().isNotEmpty ?? false
              ? data['nome']
              : 'Aluno');
      alunosComDados.add(
        _AlunoDisplayInfo(
          id: doc.id,
          nome: nomeAluno,
          fotoUrl: usuario?.fotoUrl,
          geoPoint: geoPoint,
        ),
      );
    }
    return alunosComDados;
  }

  void _pintarAlunosCacheados() {
    final cached = LocalCacheService.instance.getCachedAlunos();
    if (cached.isEmpty) return;
    _alunoMarkersData.clear();
    for (final aluno in cached) {
      final lat = aluno['lat'];
      final lng = aluno['lng'];
      if (lat is num && lng is num) {
        _addMarker(
          LatLng(lat.toDouble(), lng.toDouble()),
          aluno['nome'] as String? ?? 'Aluno',
          "",
          BitmapDescriptor.hueGreen,
          markerId: 'aluno_${aluno['id']}',
          alunoNome: aluno['nome'] as String?,
          alunoFotoUrl: aluno['fotoUrl'] as String?,
          alunoId: aluno['id'] as String?,
        );
      }
    }
    setState(() {});
  }

  Future<_AlunosBatchResult> _fetchAlunosInBatches(
      List<String> alunosIds) async {
    if (alunosIds.isEmpty) {
      return const _AlunosBatchResult([], false);
    }

    final firestore = FirebaseFirestore.instance;
    final List<DocumentSnapshot<Map<String, dynamic>>> snapshots = [];
    var hadPermissionErrors = false;

    for (final alunoId in alunosIds) {
      try {
        final snapshot = await firestore.collection('alunos').doc(alunoId).get();
        if (snapshot.exists) {
          snapshots.add(snapshot);
        }
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          debugPrint('Sem permissão para acessar dados do aluno $alunoId');
          hadPermissionErrors = true;
        } else {
          rethrow;
        }
      }
    }

    return _AlunosBatchResult(snapshots, hadPermissionErrors);
  }

  void _animateCameraToNavigation(
      LatLng focus, List<LatLng> polylinePoints) {
    if (polylinePoints.isEmpty) return;
    if (_mapController == null) return;
    LatLng directionTarget;
    if (polylinePoints.length > 1) {
      directionTarget = polylinePoints[1];
    } else {
      directionTarget = polylinePoints.first;
    }
    final bearing = _calculateBearing(focus, directionTarget);
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: focus,
          zoom: 16.5,
          tilt: 60,
          bearing: bearing,
        ),
      ),
    );
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final dLon = (end.longitude - start.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x);
    return (brng * 180 / math.pi + 360) % 360;
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

      final alunosComDados = await _fetchAlunosComUsuario(alunosIds);

      if (alunosComDados.isEmpty) {
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

      final List<LatLng> waypoints = alunosComDados
          .map((entry) => LatLng(entry.geoPoint.latitude, entry.geoPoint.longitude))
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
              ?.map((index) => alunosComDados[index])
              .toList() ??
          alunosComDados;

      _markers.clear();
      _alunoMarkersData.clear();
      for (final entry in orderedStops) {
        _addMarker(
          LatLng(entry.geoPoint.latitude, entry.geoPoint.longitude),
          entry.nome,
          "Parada do Aluno",
          BitmapDescriptor.hueGreen,
          markerId: 'aluno_${entry.id}',
          alunoNome: entry.nome,
          alunoFotoUrl: entry.fotoUrl,
          alunoId: entry.id,
        );
      }

      _addMarker(destinoFinal, "Destino Final", rota.nome, BitmapDescriptor.hueRed);

      final polylineData = directionsInfo.polylinePoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList();
      final paradasData = orderedStops
          .map((entry) => {
                'lat': entry.geoPoint.latitude,
                'lng': entry.geoPoint.longitude,
              })
          .toList();
      // Cache rota atual para uso offline
      await LocalCacheService.instance.cacheRotaAtual({
        'rotaId': rota.id,
        'polyline': polylineData,
        'paradas': paradasData,
        'destino': {'lat': destinoFinal.latitude, 'lng': destinoFinal.longitude},
      });
      await FirebaseFirestore.instance.collection('rotas').doc(rotaId).update({
        'polylineRota': polylineData,
        'paradasOrdenadas': paradasData,
        'destino': {'lat': destinoFinal.latitude, 'lng': destinoFinal.longitude},
      });

      setState(() {
        _rotaAtual = rota;
        _directionsInfo = directionsInfo;
        _rotaSequenciaParadas
          ..clear()
          ..addAll(orderedStops.map((entry) => entry.nome))
          ..add(rota.localDestinoNome);
        _polylines.clear();
        _addStyledPolyline('rota_coleta', directionsInfo.polylinePoints, Colors.blueAccent);
        _calculandoRota = false;
      });
      _animateCameraToNavigation(motoristaLocation, directionsInfo.polylinePoints);
    } catch (e) {
      final cached = LocalCacheService.instance.getCachedRotaAtual();
      if (cached != null && cached['polyline'] != null) {
        final points = (cached['polyline'] as List<dynamic>)
            .map(_parseLatLng)
            .whereType<LatLng>()
            .toList();
        final paradas = (cached['paradas'] as List<dynamic>?)
                ?.map(_parseLatLng)
                .whereType<LatLng>()
                .toList() ??
            [];
        final destino = _parseLatLng(cached['destino']);
        if (points.isNotEmpty && destino != null && mounted) {
          setState(() {
            _polylines
              ..clear()
              ..add(Polyline(
                polylineId: const PolylineId('rota_cache'),
                color: Colors.blueAccent,
                width: 6,
                points: points,
              ));
            _markers.removeWhere((m) =>
                m.markerId.value == 'destino' ||
                m.markerId.value.startsWith('parada_'));
            for (var i = 0; i < paradas.length; i++) {
              _markers.add(
                Marker(
                  markerId: MarkerId('parada_$i'),
                  position: paradas[i],
                  icon:
                      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  infoWindow: InfoWindow(
                    title: AppLocalizations.of(context)!.stopLabel((i + 1).toString()),
                  ),
                ),
              );
            }
            _markers.add(Marker(
              markerId: const MarkerId('destino'),
              position: destino,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(title: AppLocalizations.of(context)!.destinationCache),
            ));
          });
        }
      }
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

  Future<void> _finalizarViagem() async {
    if (_rotaAtual == null) return;
    
    await FirebaseFirestore.instance.collection('rotas').doc(_rotaAtual!.id).update({
      'status': StatusRota.planejada.name,
      'polylineRota': FieldValue.delete(),
      'paradasOrdenadas': FieldValue.delete(),
      'destino': FieldValue.delete(),
    });

    setState(() {
      _polylines.clear();
      _markers.clear();
      _rotaEmAndamentoId = null;
      _rotaAtual = null;
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

      final alunosComDados = await _fetchAlunosComUsuario(alunosIds);

      _alunoMarkersData.clear();
      for (final aluno in alunosComDados) {
        final localizacao = aluno.geoPoint;
        _addMarker(
          LatLng(localizacao.latitude, localizacao.longitude),
          aluno.nome,
          "",
          BitmapDescriptor.hueGreen,
          markerId: 'aluno_${aluno.id}',
          alunoNome: aluno.nome,
          alunoFotoUrl: aluno.fotoUrl,
          alunoId: aluno.id,
        );
      }
      // cache local para uso offline
      final cachePayload = alunosComDados
          .map((a) => {
                'id': a.id,
                'nome': a.nome,
                'fotoUrl': a.fotoUrl,
                'lat': a.geoPoint.latitude,
                'lng': a.geoPoint.longitude,
              })
          .toList();
      await LocalCacheService.instance.cacheAlunos(cachePayload);
      if (mounted) {
        setState(() {
          _directionsInfo = null;
          _rotaSequenciaParadas.clear();
        });
      }
    } catch (e) {
      _pintarAlunosCacheados();
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
          MaterialPageRoute(builder: (_) => const TelaSelecao()),
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
    _mapController = controller;
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
    if (_selectedIndex == 4) return;
    setState(() {
      _selectedIndex = 4;
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
                size: 90, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
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
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isLoggedIn = userId.isNotEmpty;

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
          buildingsEnabled: false,
          mapType: MapType.normal,
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
          top: 16,
          child: _RouteSummaryPanel(
            directionsInfo: _directionsInfo,
            stops: _rotaSequenciaParadas,
            isExpanded: _mostrarResumoRota,
            onToggle: () {
              setState(() {
                _mostrarResumoRota = !_mostrarResumoRota;
              });
            },
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: isLoggedIn
          ? NeonAppBar(
              title: _getAppBarTitle(_selectedIndex),
              onNotificationsPressed: _openNotifications,
              notificationAction: NotificationsBell(
                role: UserRole.motorista,
                userId: userId,
                onPressed: _openNotifications,
              ),
            )
          : null,
      drawer: isLoggedIn
          ? NeonDrawer(
              title: 'Menu do Motorista',
              onSettings: _navigateToSettings,
              onLogout: _logout,
            )
          : null,
      floatingActionButton: _rotaEmAndamentoId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _finalizarViagem,
              label: const Text('Finalizar Viagem'),
              icon: const Icon(Icons.done_all),
            ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          mapaWidget,
          if (isLoggedIn)
            const TelaViagem()
          else
            _buildLoginPromptWidget(context),
          if (isLoggedIn)
            const TelaGerenciarAlunos(showAppBar: false)
          else
            _buildLoginPromptWidget(context),
          isLoggedIn
              ? const TelaListaChats(showAppBar: false)
              : _buildLoginPromptWidget(context),
          isLoggedIn
              ? const PerfilScreen(
                  collectionPath: 'motoristas',
                  showAppBar: false,
                )
              : _buildLoginPromptWidget(context),
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
