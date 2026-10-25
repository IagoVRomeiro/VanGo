import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:vango/config/api_keys.dart';
import 'package:vango/config/map_styles.dart';
import 'package:vango/models/directions_info.dart';
import 'package:vango/models/rota.dart';
import 'package:vango/services/distance_matrix_service.dart';
import 'package:vango/services/directions_service.dart';
import 'package:vango/services/local_cache.dart';
import 'package:vango/services/navigation_marker_factory.dart';
import 'package:vango/services/permission_service.dart';
import 'package:vango/services/route_progress.dart';
import 'package:vango/services/voice_navigation_service.dart';
import 'package:vango/services/voice_settings_service.dart';
import 'package:vango/l10n/app_localizations.dart';
import '../models/usuario.dart';
import 'package:vango/screens/tela_configuracoes.dart';
import 'tela_cadastro.dart';
import 'tela_gerenciar_alunos.dart';
import 'tela_lista_chats.dart';
import 'tela_login.dart';
import 'tela_selecao.dart';
import 'tela_convites.dart';
import 'tela_notificacoes.dart';
import 'tela_perfil.dart';
import 'tela_viagem.dart';
import 'tela_historico_viagens.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bottom_nav_bar.dart';
import '../widgets/neon_drawer.dart';
import '../widgets/notifications_bell.dart';
import '../widgets/messages_badge.dart';

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

class _NextStopInfo {
  final String label;
  final LatLng location;
  final bool isDestination;

  const _NextStopInfo({
    required this.label,
    required this.location,
    this.isDestination = false,
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
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
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
                  icon:
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
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
                    final label = index == stops.length - 1
                        ? 'Destino'
                        : 'Parada ${index + 1}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.8),
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
                                  style: theme.textTheme.labelMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
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

class _ManeuverBanner extends StatelessWidget {
  final IconData icon;
  final String distanceText;
  final String instruction;

  const _ManeuverBanner({
    required this.icon,
    required this.distanceText,
    required this.instruction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF15171B).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFB5FF2A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.black, size: 38),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  distanceText,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  instruction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedBadge extends StatelessWidget {
  final double? speedKmh;

  const _SpeedBadge({required this.speedKmh});

  @override
  Widget build(BuildContext context) {
    final speed = (speedKmh ?? 0).clamp(0, 240).toStringAsFixed(0);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            speed,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const Text(
            'km/h',
            style: TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _NavigationFooter extends StatelessWidget {
  final String destination;
  final String? distance;
  final String? duration;
  final bool isTrafficAware;
  final String? nextStopEta;
  final String? nextStopLabel;

  const _NavigationFooter({
    required this.destination,
    required this.distance,
    required this.duration,
    required this.isTrafficAware,
    required this.nextStopEta,
    required this.nextStopLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String metricsText;
    if (nextStopEta != null && nextStopEta!.isNotEmpty) {
      final label = nextStopLabel?.trim();
      metricsText =
          'Próxima: $nextStopEta${label == null || label.isEmpty ? '' : ' · $label'}';
    } else {
      metricsText = [
        if (duration != null && duration!.isNotEmpty) duration!,
        if (distance != null && distance!.isNotEmpty) distance!,
      ].join(' · ');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
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
        children: [
          Expanded(
            child: Text(
              metricsText.isNotEmpty ? metricsText : destination,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isTrafficAware)
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.traffic, size: 16, color: Colors.black45),
            ),
        ],
      ),
    );
  }
}

class _TelaMotoristaState extends State<TelaMotorista>
    with SingleTickerProviderStateMixin {
  static const int _etaMinIntervalSeconds = 45;
  static const double _etaOriginMoveMeters = 120;
  static const double _etaDestinationMoveMeters = 40;
  static const double _stopReachedThresholdMeters = 120;
  static const double _voicePromptDistanceMeters = 140;
  static const int _voiceMinIntervalSeconds = 8;
  static const double _snapToRouteMeters = 30;
  static const double _offRouteThresholdMeters = 45;
  static const int _offRouteConfirmations = 3;
  static const int _rerouteMinIntervalSeconds = 20;
  static const int _locationSyncMinIntervalSeconds = 4;
  static const double _locationSyncMinMoveMeters = 25;
  static const double _gpsHeadingMinSpeedMs = 2.5;
  static const double _navigationTilt = 55;
  static const Duration _driverAnimationDuration = Duration(milliseconds: 900);
  static const Duration _driverFrameInterval = Duration(milliseconds: 40);

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Map<String, _AlunoMarkerData> _alunoMarkersData = {};
  late int _selectedIndex;
  final String _apiKey = googleApiKey;

  // State for Trip Mode
  String? _rotaEmAndamentoId;
  Rota? _rotaAtual;
  DirectionsInfo? _directionsInfo;
  final List<String> _rotaSequenciaParadas = [];
  final List<_NextStopInfo> _remainingStops = [];
  final List<RouteStepInfo> _routeSteps = [];
  int _currentStepIndex = 0;
  int _lastSpokenStepIndex = -1;
  DateTime? _lastVoicePromptAt;
  final VoiceNavigationService _voiceNavigationService =
      VoiceNavigationService();
  late final VoidCallback _voiceSettingsListener;
  DistanceMatrixService? _distanceMatrixService;
  String? _nextStopEtaText;
  String? _nextStopLabel;
  bool _isFetchingNextEta = false;
  DateTime? _lastNextEtaFetchAt;
  LatLng? _lastNextEtaOrigin;
  LatLng? _lastNextEtaDestination;
  bool _calculandoRota = false;
  bool _mostrarResumoRota = true;
  double? _currentSpeedKmh;

  // Navegação no estilo Waze
  RouteProgressTracker? _routeTracker;
  double _distanceToManeuver = 0;
  double? _distanceToNextStop;
  int _offRouteCount = 0;
  bool _isRerouting = false;
  DateTime? _lastRerouteAt;
  bool _followDriver = true;
  BitmapDescriptor? _driverArrowIcon;
  late final AnimationController _driverAnimation;
  LatLng? _driverFrom;
  LatLng? _driverTo;
  double _headingFrom = 0;
  double _headingTo = 0;
  LatLng? _displayedDriverPosition;
  double _displayedHeading = 0;
  double _cameraZoom = 17.5;
  DateTime _lastDriverFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _hasCenteredOnDriver = false;
  DateTime? _lastLocationSyncAt;
  LatLng? _lastLocationSyncPosition;

  // State for Live Location
  final PermissionService _permissionService = PermissionService();
  StreamSubscription<Position>? _positionStreamSubscription;

  bool get _isNavigating =>
      _rotaEmAndamentoId != null &&
      _directionsInfo != null &&
      _routeTracker != null;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _distanceMatrixService = DistanceMatrixService(apiKey: _apiKey);
    _voiceNavigationService.init();
    _voiceNavigationService.setEnabled(voiceSettingsService.value);
    _voiceSettingsListener = () {
      _voiceNavigationService.setEnabled(voiceSettingsService.value);
    };
    voiceSettingsService.addListener(_voiceSettingsListener);
    _driverAnimation = AnimationController(
      vsync: this,
      duration: _driverAnimationDuration,
    )..addListener(_onDriverAnimationTick);
    NavigationMarkerFactory.driverArrow().then((icon) {
      if (mounted) setState(() => _driverArrowIcon = icon);
    });
    _loadApiKeyAndData();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _driverAnimation.dispose();
    WakelockPlus.disable();
    _mapController?.dispose();
    _voiceNavigationService.stop();
    voiceSettingsService.removeListener(_voiceSettingsListener);
    super.dispose();
  }

  void _loadApiKeyAndData() async {
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

  LocationSettings _navigationLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 2,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );
  }

  void _startLocationUpdates() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: _navigationLocationSettings(),
    ).listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position position) {
    final driverLatLng = LatLng(position.latitude, position.longitude);
    final speedMs = position.speed.isNaN ? 0.0 : math.max(0.0, position.speed);
    final gpsHeadingValid = speedMs >= _gpsHeadingMinSpeedMs &&
        !position.heading.isNaN &&
        position.heading >= 0;

    var displayPosition = driverLatLng;
    var heading = gpsHeadingValid ? position.heading : _displayedHeading;

    if (_isNavigating) {
      final snapshot = _routeTracker!.update(driverLatLng);
      if (snapshot != null) {
        if (snapshot.distanceFromRoute <= _snapToRouteMeters) {
          // Como no Waze: a seta "gruda" na rua enquanto o motorista
          // estiver na rota.
          displayPosition = snapshot.projected;
          heading = snapshot.segmentBearing;
        }
        _updateRouteProgress(snapshot, driverLatLng);
      }
    }

    setState(() {
      _currentSpeedKmh = speedMs * 3.6;
    });

    if (_isNavigating) {
      _animateDriverTo(displayPosition, heading);
    } else if (!_hasCenteredOnDriver && _mapController != null) {
      _hasCenteredOnDriver = true;
      _mapController!
          .animateCamera(CameraUpdate.newLatLngZoom(driverLatLng, 15));
    }

    if (_rotaEmAndamentoId != null && _remainingStops.isNotEmpty) {
      _updateNextStopProgress(driverLatLng);
    }
    if (_rotaEmAndamentoId != null) {
      _syncDriverLocation(driverLatLng);
    }
  }

  void _updateRouteProgress(RouteSnapshot snapshot, LatLng driverLatLng) {
    final tracker = _routeTracker!;
    final along = snapshot.distanceAlongRoute;
    final stepIndex = tracker.stepIndexFor(along);
    _currentStepIndex = stepIndex.clamp(0, _routeSteps.length);
    _distanceToManeuver = _currentStepIndex < _routeSteps.length
        ? tracker.distanceToStepEnd(_currentStepIndex, along)
        : math.max(0, tracker.totalLength - along);

    _polylines.clear();
    _addStyledPolyline(
      'rota_coleta',
      tracker.remainingPoints(snapshot),
      const Color(0xFF6D4CFF),
    );

    _updateVoiceGuidance();

    if (snapshot.distanceFromRoute > _offRouteThresholdMeters) {
      _offRouteCount++;
      if (_offRouteCount >= _offRouteConfirmations) {
        _reroute(driverLatLng);
      }
    } else {
      _offRouteCount = 0;
    }
  }

  void _animateDriverTo(LatLng position, double heading) {
    final from = _displayedDriverPosition ?? position;
    _driverFrom = from;
    _driverTo = position;
    _headingFrom = _displayedHeading;
    // Gira pelo menor ângulo (ex.: de 350° para 10° passa por 0°).
    final delta = ((heading - _displayedHeading + 540) % 360) - 180;
    _headingTo = _displayedHeading + delta;

    final speed = _currentSpeedKmh ?? 0;
    final targetZoom = speed < 20
        ? 18.0
        : speed < 45
            ? 17.4
            : speed < 75
                ? 16.8
                : 16.2;
    _cameraZoom += (targetZoom - _cameraZoom) * 0.35;

    _driverAnimation.forward(from: 0);
  }

  void _onDriverAnimationTick() {
    final from = _driverFrom;
    final to = _driverTo;
    if (from == null || to == null) return;

    final now = DateTime.now();
    final isLastFrame = _driverAnimation.value >= 1;
    if (!isLastFrame &&
        now.difference(_lastDriverFrameAt) < _driverFrameInterval) {
      return;
    }
    _lastDriverFrameAt = now;

    final t = _driverAnimation.value;
    final position = LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
    final heading =
        (_headingFrom + (_headingTo - _headingFrom) * t + 360) % 360;

    setState(() {
      _displayedDriverPosition = position;
      _displayedHeading = heading;
    });

    if (_followDriver && _isNavigating) {
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: _cameraZoom,
            tilt: _navigationTilt,
            bearing: heading,
          ),
        ),
      );
    }
  }

  void _recenterOnDriver() {
    setState(() => _followDriver = true);
    final position = _displayedDriverPosition;
    if (position == null) return;
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: _cameraZoom,
          tilt: _navigationTilt,
          bearing: _displayedHeading,
        ),
      ),
    );
  }

  Future<void> _syncDriverLocation(LatLng position) async {
    final lastSync = _lastLocationSyncAt;
    final lastPosition = _lastLocationSyncPosition;
    if (lastSync != null && lastPosition != null) {
      final elapsed = DateTime.now().difference(lastSync).inSeconds;
      final moved = RouteProgressTracker.distanceMeters(lastPosition, position);
      if (elapsed < _locationSyncMinIntervalSeconds &&
          moved < _locationSyncMinMoveMeters) {
        return;
      }
    }
    _lastLocationSyncAt = DateTime.now();
    _lastLocationSyncPosition = position;
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
      debugPrint('Erro ao atualizar localização do motorista na rota: $e');
    }
  }

  Future<void> _reroute(LatLng origin) async {
    if (_isRerouting || _remainingStops.isEmpty) return;
    final lastReroute = _lastRerouteAt;
    if (lastReroute != null &&
        DateTime.now().difference(lastReroute).inSeconds <
            _rerouteMinIntervalSeconds) {
      return;
    }
    _isRerouting = true;
    _lastRerouteAt = DateTime.now();
    _voiceNavigationService.speak('Recalculando rota.');
    if (mounted) setState(() {});

    final destination = _remainingStops.last.location;
    final waypoints = _remainingStops
        .where((stop) => !stop.isDestination)
        .map((stop) => stop.location)
        .toList();
    final directionsInfo =
        await DirectionsService(apiKey: _apiKey).getDirections(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      optimizeWaypoints: false,
    );

    _isRerouting = false;
    _offRouteCount = 0;
    if (!mounted || directionsInfo == null || _rotaEmAndamentoId == null) {
      if (mounted) setState(() {});
      return;
    }

    setState(() {
      _directionsInfo = directionsInfo;
      _routeTracker = RouteProgressTracker(
        directionsInfo.polylinePoints,
        directionsInfo.steps.map((step) => step.endLocation).toList(),
      );
      _routeSteps
        ..clear()
        ..addAll(directionsInfo.steps);
      _currentStepIndex = 0;
      _lastSpokenStepIndex = 0;
      _polylines.clear();
      _addStyledPolyline('rota_coleta', directionsInfo.polylinePoints,
          const Color(0xFF6D4CFF));
    });

    try {
      await FirebaseFirestore.instance
          .collection('rotas')
          .doc(_rotaEmAndamentoId)
          .update({
        'polylineRota': directionsInfo.polylinePoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
      });
    } catch (e) {
      debugPrint('Erro ao salvar rota recalculada: $e');
    }
  }

  void _addMarker(LatLng position, String title, String snippet, double hue,
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
                      data.fotoUrl != null && data.fotoUrl!.isNotEmpty
                          ? NetworkImage(data.fotoUrl!)
                          : null,
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
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      FutureBuilder<List<String>>(
                        future: rotasDoAluno(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Text(
                                AppLocalizations.of(context)!.loadingRoutes);
                          }
                          final rotas = snapshot.data ?? [];
                          if (rotas.isEmpty) {
                            return Text(
                                AppLocalizations.of(context)!.noRoutesLinked);
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: rotas
                                .map((rotaNome) => Text(
                                      AppLocalizations.of(context)!
                                          .routeLabel(rotaNome),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
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
        color: color.withValues(alpha: 0.2),
        width: 22,
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
        width: 11,
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
          content: Text(
              'Alguns passageiros não puderam ser carregados. Verifique se estão vinculados ao motorista.'),
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
        final snapshot =
            await firestore.collection('alunos').doc(alunoId).get();
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

  void _updateNextStopProgress(LatLng driverLatLng) {
    if (_remainingStops.isEmpty) return;
    final nextStop = _remainingStops.first;
    final distance = Geolocator.distanceBetween(
      driverLatLng.latitude,
      driverLatLng.longitude,
      nextStop.location.latitude,
      nextStop.location.longitude,
    );
    _distanceToNextStop = distance;
    if (distance <= _stopReachedThresholdMeters) {
      if (nextStop.isDestination) {
        _voiceNavigationService.speak('Você chegou ao destino.');
      } else {
        _voiceNavigationService
            .speak('Chegando na parada de ${nextStop.label}.');
      }
      _remainingStops.removeAt(0);
      _nextStopEtaText = null;
      _lastNextEtaFetchAt = null;
      _lastNextEtaOrigin = null;
      _lastNextEtaDestination = null;
      _nextStopLabel =
          _remainingStops.isNotEmpty ? _remainingStops.first.label : null;
      if (mounted) {
        setState(() {});
      }
    }

    if (_remainingStops.isEmpty) return;
    _updateNextStopEta(driverLatLng, _remainingStops.first.location);
  }

  bool _shouldFetchNextEta(LatLng origin, LatLng destination) {
    final lastFetch = _lastNextEtaFetchAt;
    if (lastFetch == null) return true;
    final elapsed = DateTime.now().difference(lastFetch);
    if (elapsed.inSeconds >= _etaMinIntervalSeconds) return true;
    if (_lastNextEtaOrigin == null || _lastNextEtaDestination == null) {
      return true;
    }
    final movedOrigin = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      _lastNextEtaOrigin!.latitude,
      _lastNextEtaOrigin!.longitude,
    );
    final movedDestination = Geolocator.distanceBetween(
      destination.latitude,
      destination.longitude,
      _lastNextEtaDestination!.latitude,
      _lastNextEtaDestination!.longitude,
    );
    return movedOrigin >= _etaOriginMoveMeters ||
        movedDestination >= _etaDestinationMoveMeters;
  }

  Future<void> _updateNextStopEta(LatLng origin, LatLng destination) async {
    if (_distanceMatrixService == null || _isFetchingNextEta) return;
    if (!_shouldFetchNextEta(origin, destination)) return;
    _isFetchingNextEta = true;
    _lastNextEtaFetchAt = DateTime.now();
    _lastNextEtaOrigin = origin;
    _lastNextEtaDestination = destination;

    final metrics = await _distanceMatrixService!.fetchDriveMetrics(
      origin: origin,
      destination: destination,
    );

    if (!mounted) {
      _isFetchingNextEta = false;
      return;
    }

    final seconds =
        metrics?.durationInTrafficSeconds ?? metrics?.durationSeconds;
    setState(() {
      _nextStopEtaText = _formatDurationSeconds(seconds);
    });
    _isFetchingNextEta = false;
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

  void _announceInitialStep() {
    if (_routeSteps.isEmpty) return;
    final instruction = _routeSteps.first.instruction;
    if (instruction.isEmpty) return;
    _voiceNavigationService.speak('Iniciando rota. $instruction');
    _lastSpokenStepIndex = 0;
    _lastVoicePromptAt = DateTime.now();
  }

  /// Fala a próxima manobra: enquanto o motorista percorre o passo N,
  /// a manobra seguinte é a instrução do passo N + 1, no fim do passo N.
  void _updateVoiceGuidance() {
    final nextIndex = _currentStepIndex + 1;
    if (nextIndex >= _routeSteps.length) return;
    if (_lastSpokenStepIndex >= nextIndex) return;
    if (_distanceToManeuver > _voicePromptDistanceMeters) return;

    final now = DateTime.now();
    final lastPrompt = _lastVoicePromptAt;
    if (lastPrompt != null &&
        now.difference(lastPrompt).inSeconds < _voiceMinIntervalSeconds) {
      return;
    }

    final instruction = _routeSteps[nextIndex].instruction;
    if (_distanceToManeuver >= 50) {
      final rounded = (_distanceToManeuver / 50).round() * 50;
      final lowered = instruction.isEmpty
          ? instruction
          : instruction[0].toLowerCase() + instruction.substring(1);
      _voiceNavigationService.speak('Em $rounded metros, $lowered');
    } else {
      _voiceNavigationService.speak(instruction);
    }
    _lastSpokenStepIndex = nextIndex;
    _lastVoicePromptAt = now;
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
      final rotaDoc = await FirebaseFirestore.instance
          .collection('rotas')
          .doc(rotaId)
          .get();
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
              content: Text(
                  "Nenhum aluno desta rota possui localização cadastrada."),
            ),
          );
          setState(() => _calculandoRota = false);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final motoristaLocation = LatLng(position.latitude, position.longitude);

      final destinoFinal =
          LatLng(rota.localDestino.latitude, rota.localDestino.longitude);

      final List<LatLng> waypoints = alunosComDados
          .map((entry) =>
              LatLng(entry.geoPoint.latitude, entry.geoPoint.longitude))
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
      final nextStops = [
        ...orderedStops.map(
          (entry) => _NextStopInfo(
            label: entry.nome,
            location: LatLng(entry.geoPoint.latitude, entry.geoPoint.longitude),
          ),
        ),
        _NextStopInfo(
          label: rota.localDestinoNome.isNotEmpty
              ? rota.localDestinoNome
              : 'Destino',
          location: destinoFinal,
          isDestination: true,
        ),
      ];

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

      _addMarker(
          destinoFinal, "Destino Final", rota.nome, BitmapDescriptor.hueRed);

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
        'destino': {
          'lat': destinoFinal.latitude,
          'lng': destinoFinal.longitude
        },
      });
      await FirebaseFirestore.instance.collection('rotas').doc(rotaId).update({
        'polylineRota': polylineData,
        'paradasOrdenadas': paradasData,
        'destino': {
          'lat': destinoFinal.latitude,
          'lng': destinoFinal.longitude
        },
      });

      setState(() {
        _rotaAtual = rota;
        _directionsInfo = directionsInfo;
        _rotaSequenciaParadas
          ..clear()
          ..addAll(orderedStops.map((entry) => entry.nome))
          ..add(rota.localDestinoNome);
        _routeSteps
          ..clear()
          ..addAll(directionsInfo.steps);
        _routeTracker = RouteProgressTracker(
          directionsInfo.polylinePoints,
          directionsInfo.steps.map((step) => step.endLocation).toList(),
        );
        _currentStepIndex = 0;
        _lastSpokenStepIndex = -1;
        _lastVoicePromptAt = null;
        _offRouteCount = 0;
        _followDriver = true;
        _remainingStops
          ..clear()
          ..addAll(nextStops);
        _nextStopLabel =
            _remainingStops.isNotEmpty ? _remainingStops.first.label : null;
        _nextStopEtaText = null;
        _lastNextEtaFetchAt = null;
        _lastNextEtaOrigin = null;
        _lastNextEtaDestination = null;
        _polylines.clear();
        _addStyledPolyline('rota_coleta', directionsInfo.polylinePoints,
            const Color(0xFF6D4CFF));
        _calculandoRota = false;
      });
      _announceInitialStep();
      if (_rotaEmAndamentoId != null) {
        WakelockPlus.enable();
        _displayedDriverPosition = null;
        _displayedHeading = RouteProgressTracker.bearingDegrees(
          directionsInfo.polylinePoints.first,
          directionsInfo.polylinePoints[
              math.min(5, directionsInfo.polylinePoints.length - 1)],
        );
        _animateDriverTo(motoristaLocation, _displayedHeading);
      }
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
          final cachedStops = <_NextStopInfo>[
            for (var i = 0; i < paradas.length; i++)
              _NextStopInfo(
                label: 'Parada ${i + 1}',
                location: paradas[i],
              ),
            _NextStopInfo(
              label: 'Destino',
              location: destino,
              isDestination: true,
            ),
          ];
          setState(() {
            _polylines
              ..clear()
              ..add(Polyline(
                polylineId: const PolylineId('rota_cache'),
                color: const Color(0xFF6D4CFF),
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
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen),
                  infoWindow: InfoWindow(
                    title: AppLocalizations.of(context)!
                        .stopLabel((i + 1).toString()),
                  ),
                ),
              );
            }
            _markers.add(Marker(
              markerId: const MarkerId('destino'),
              position: destino,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                  title: AppLocalizations.of(context)!.destinationCache),
            ));
            _remainingStops
              ..clear()
              ..addAll(cachedStops);
            _nextStopLabel =
                _remainingStops.isNotEmpty ? _remainingStops.first.label : null;
            _routeSteps.clear();
            _currentStepIndex = 0;
            _lastSpokenStepIndex = -1;
            _lastVoicePromptAt = null;
            _nextStopEtaText = null;
            _lastNextEtaFetchAt = null;
            _lastNextEtaOrigin = null;
            _lastNextEtaDestination = null;
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

    await FirebaseFirestore.instance
        .collection('rotas')
        .doc(_rotaAtual!.id)
        .update({
      'status': StatusRota.concluida.name,
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
      _routeSteps.clear();
      _currentStepIndex = 0;
      _lastSpokenStepIndex = -1;
      _lastVoicePromptAt = null;
      _remainingStops.clear();
      _nextStopLabel = null;
      _nextStopEtaText = null;
      _lastNextEtaFetchAt = null;
      _lastNextEtaOrigin = null;
      _lastNextEtaDestination = null;
      _routeTracker = null;
      _distanceToNextStop = null;
      _displayedDriverPosition = null;
      _followDriver = true;
      _carregarAlunosNoMapa();
    });
    WakelockPlus.disable();
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _lastLocationSyncPosition ?? const LatLng(-19.9245, -43.9352),
          zoom: 15,
        ),
      ),
    );
  }

  Future<void> _carregarAlunosNoMapa() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (mounted) {
        setState(() => _calculandoRota = false);
      }
      final motoristaDoc = await FirebaseFirestore.instance
          .collection('motoristas')
          .doc(user.uid)
          .get();
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro ao sair: $e")));
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
          context, MaterialPageRoute(builder: (_) => const TelaLogin()));
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
      MaterialPageRoute(builder: (context) => TelaConvites()),
    );
  }

  Future<void> _openHistorico() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TelaHistoricoViagens.motorista(),
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
                size: 90,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
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
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  ({IconData icon, String distance, String instruction})?
      _maneuverBannerData() {
    if (!_isNavigating) return null;
    final nextStop = _remainingStops.isNotEmpty ? _remainingStops.first : null;
    final nextIndex = _currentStepIndex + 1;
    final hasManeuver = nextIndex < _routeSteps.length;
    final stopDistance = _distanceToNextStop;

    if (nextStop != null &&
        !nextStop.isDestination &&
        stopDistance != null &&
        (!hasManeuver || stopDistance <= _distanceToManeuver)) {
      return (
        icon: Icons.person_pin_circle,
        distance: _formatBannerDistance(stopDistance),
        instruction: 'Parada: ${nextStop.label}',
      );
    }
    if (!hasManeuver) {
      return (
        icon: Icons.flag,
        distance: _formatBannerDistance(_distanceToManeuver),
        instruction: nextStop?.label ?? 'Destino',
      );
    }
    final step = _routeSteps[nextIndex];
    return (
      icon: _maneuverIcon(step.maneuver),
      distance: _formatBannerDistance(_distanceToManeuver),
      instruction: step.instruction,
    );
  }

  String _formatBannerDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
    }
    if (meters < 20) return 'Agora';
    return '${(meters / 10).round() * 10} m';
  }

  IconData _maneuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'turn-left':
        return Icons.turn_left;
      case 'turn-right':
        return Icons.turn_right;
      case 'turn-slight-left':
      case 'keep-left':
        return Icons.turn_slight_left;
      case 'turn-slight-right':
      case 'keep-right':
        return Icons.turn_slight_right;
      case 'turn-sharp-left':
        return Icons.turn_sharp_left;
      case 'turn-sharp-right':
        return Icons.turn_sharp_right;
      case 'uturn-left':
        return Icons.u_turn_left;
      case 'uturn-right':
        return Icons.u_turn_right;
      case 'roundabout-left':
        return Icons.roundabout_left;
      case 'roundabout-right':
        return Icons.roundabout_right;
      case 'ramp-left':
        return Icons.ramp_left;
      case 'ramp-right':
        return Icons.ramp_right;
      case 'fork-left':
        return Icons.fork_left;
      case 'fork-right':
        return Icons.fork_right;
      case 'merge':
        return Icons.merge;
      case 'ferry':
      case 'ferry-train':
        return Icons.directions_boat;
      default:
        return Icons.straight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isLoggedIn = userId.isNotEmpty;
    final bool showNavigationUI =
        _rotaEmAndamentoId != null && _directionsInfo != null;
    final String destinationLabel =
        _rotaAtual?.localDestinoNome ?? _rotaAtual?.nome ?? 'Destino';
    final bool isNavigating = _isNavigating;
    final banner = _maneuverBannerData();
    final driverPosition = _displayedDriverPosition;
    final bool useDarkMapStyle =
        isNavigating && Theme.of(context).brightness == Brightness.dark;

    Widget mapaWidget = LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Listener(
            onPointerDown: (_) {
              if (isNavigating && _followDriver) {
                setState(() => _followDriver = false);
              }
            },
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: const CameraPosition(
                  target: LatLng(-19.9245, -43.9352), zoom: 12.0),
              markers: {
                ..._markers,
                if (isNavigating &&
                    driverPosition != null &&
                    _driverArrowIcon != null)
                  Marker(
                    markerId: const MarkerId('driver'),
                    position: driverPosition,
                    icon: _driverArrowIcon!,
                    rotation: _displayedHeading,
                    flat: true,
                    anchor: const Offset(0.5, 0.5),
                    zIndexInt: 10,
                  ),
              },
              polylines: _polylines,
              style: useDarkMapStyle ? navigationDarkMapStyle : null,
              // No modo navegação o centro da câmera fica no terço inferior,
              // deixando mais rua visível à frente do motorista.
              padding: isNavigating
                  ? EdgeInsets.only(top: constraints.maxHeight * 0.42)
                  : EdgeInsets.zero,
              myLocationEnabled: !isNavigating,
              myLocationButtonEnabled: !isNavigating,
              compassEnabled: !isNavigating,
              mapToolbarEnabled: false,
              trafficEnabled: isNavigating,
              buildingsEnabled: true,
              mapType: MapType.normal,
            ),
          ),
          if (_calculandoRota)
            const Positioned(
              top: 16,
              right: 16,
              child: _RouteStatusChip(),
            ),
          if (!showNavigationUI)
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
          if (banner != null)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ManeuverBanner(
                    icon: banner.icon,
                    distanceText: banner.distance,
                    instruction: banner.instruction,
                  ),
                  if (_isRerouting)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Chip(
                        avatar: const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        label: const Text('Recalculando rota...'),
                        backgroundColor: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                ],
              ),
            ),
          if (isNavigating && !_followDriver)
            Positioned(
              right: 16,
              bottom: 100,
              child: FloatingActionButton.extended(
                heroTag: 'recentralizar',
                onPressed: _recenterOnDriver,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                icon: const Icon(Icons.navigation),
                label: const Text('Recentralizar'),
              ),
            ),
          if (showNavigationUI)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SpeedBadge(speedKmh: _currentSpeedKmh),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NavigationFooter(
                      destination: destinationLabel,
                      duration: _directionsInfo?.totalDuration,
                      distance: _directionsInfo?.totalDistance,
                      isTrafficAware: _directionsInfo?.isTrafficAware ?? false,
                      nextStopEta: _nextStopEtaText,
                      nextStopLabel: _nextStopLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    heroTag: 'finalizar_viagem_mapa',
                    onPressed: _finalizarViagem,
                    tooltip: 'Finalizar viagem',
                    backgroundColor: const Color(0xFFB5FF2A),
                    foregroundColor: Colors.black,
                    child: const Icon(Icons.done_all),
                  ),
                ],
              ),
            ),
        ],
      ),
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
              onNotifications: _openNotificacoesClima,
              onHistory: _openHistorico,
            )
          : null,
      floatingActionButton: _rotaEmAndamentoId == null ||
              (showNavigationUI && _selectedIndex == 0)
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 72),
              child: FloatingActionButton(
                onPressed: _finalizarViagem,
                tooltip: 'Finalizar viagem',
                mini: true,
                backgroundColor: const Color(0xFFB5FF2A),
                foregroundColor: Colors.black,
                child: const Icon(Icons.done_all),
              ),
            ),
      floatingActionButtonLocation: _rotaEmAndamentoId == null ||
              (showNavigationUI && _selectedIndex == 0)
          ? null
          : FloatingActionButtonLocation.endTop,
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
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.edit_road_outlined), label: 'Viagem'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_outlined), label: 'Alunos'),
          BottomNavigationBarItem(
            icon: MessagesBadge(userId: userId, icon: Icons.chat),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Perfil'),
        ],
        selectedColor: Theme.of(context).colorScheme.primary,
        unselectedColor: Colors.white70,
      ),
    );
  }
}
