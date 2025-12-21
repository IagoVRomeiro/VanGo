import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:vango/config/api_keys.dart';
import 'package:vango/models/rota.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/services/air_quality_service.dart';
import 'package:vango/services/pollen_service.dart';
import '../widgets/neon_app_bar.dart';

class TelaNotificacoes extends StatefulWidget {
  final bool showAppBar;

  const TelaNotificacoes({super.key, this.showAppBar = true});

  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  User? _currentUser;
  Future<UserRole>? _userRoleFuture;
  Future<_UserLocation?>? _userLocationFuture;
  _WeatherSnapshot? _weather;
  bool _weatherLoading = false;
  String? _weatherError;
  AirQualitySnapshot? _airQuality;
  bool _airQualityLoading = false;
  String? _airQualityError;
  PollenSnapshot? _pollen;
  bool _pollenLoading = false;
  String? _pollenError;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _userRoleFuture = _getUserRole(_currentUser!.uid);
      _userRoleFuture!.then(_carregarDadosAmbientais);
    }
  }

  Future<UserRole> _getUserRole(String userId) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserRole.fromString(doc.data()?['role']);
      }
      return UserRole.indefinido;
    } catch (_) {
      return UserRole.indefinido;
    }
  }

  void _carregarDadosAmbientais(UserRole role) {
    _userLocationFuture ??= _buscarLocalizacaoUsuario(role);
    _carregarClima(role);
    _carregarQualidadeAr(role);
    _carregarPolem(role);
  }

  Future<_UserLocation?> _buscarLocalizacaoUsuario(UserRole role) async {
    final userId = _currentUser?.uid;
    if (userId == null) return null;

    final collectionPath = role == UserRole.motorista ? 'motoristas' : 'alunos';
    final profileDoc = await FirebaseFirestore.instance
        .collection(collectionPath)
        .doc(userId)
        .get();
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final profileData = profileDoc.data();
    final userData = userDoc.data();
    final geo = profileData?['localizacao'] as GeoPoint?;
    if (geo == null) return null;

    final endereco = userData?['endereco'] as String?;
    final locationName = endereco == null
        ? null
        : _extractCityFromAddress(endereco.trim());

    return _UserLocation(
      geo: geo,
      locationName: locationName,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: widget.showAppBar
            ? const NeonAppBar(
                title: 'Notificações',
                showMenuButton: false,
                showBackButton: true,
                showNotificationsButton: false,
              )
            : null,
        body: const Center(
          child: Text('Faça login para ver as notificações.'),
        ),
      );
    }

    final body = FutureBuilder<UserRole>(
      future: _userRoleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final role = snapshot.data ?? UserRole.indefinido;
        if (role == UserRole.indefinido) {
          return const Center(
            child: Text('Não foi possível carregar suas notificações.'),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWeatherCard(context),
              _buildWeatherAlertsCard(context),
              _buildAirQualityCard(context),
              _buildPollenCard(context),
              _buildEnvironmentalAlertsCard(context),
              const SizedBox(height: 16),
              _buildTripSoonCard(context, role),
              _buildDriverNearCard(context, role),
            ],
          ),
        );
      },
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      appBar: const NeonAppBar(
        title: 'Notificações',
        showMenuButton: false,
        showBackButton: true,
        showNotificationsButton: false,
      ),
      body: body,
    );
  }

  Widget _buildWeatherCard(BuildContext context) {
    if (_weatherLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Carregando clima...'),
            ],
          ),
        ),
      );
    }
    if (_weatherError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_weatherError!),
        ),
      );
    }
    if (_weather == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Clima indisponível no momento.'),
        ),
      );
    }
    final weather = _weather!;
    final locationLabel = weather.locationName ?? 'sua cidade';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (weather.iconUrl != null && weather.iconUrl!.isNotEmpty)
              Image.network(
                weather.iconUrl!,
                width: 40,
                height: 40,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.wb_cloudy, size: 40),
              )
            else
              const Icon(Icons.wb_cloudy, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clima em $locationLabel',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${weather.temperatureC.toStringAsFixed(1)}°C • ${weather.description}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripSoonCard(BuildContext context, UserRole role) {
    final userId = _currentUser?.uid;
    if (userId == null) {
      return const SizedBox.shrink();
    }

    final baseQuery = FirebaseFirestore.instance
        .collection('rotas')
        .where('status', isEqualTo: StatusRota.planejada.name);
    final query = role == UserRole.motorista
        ? baseQuery.where('motoristaId', isEqualTo: userId)
        : baseQuery.where('listaAlunosIds', arrayContains: userId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Erro ao carregar as viagens futuras.'),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        final rotas = docs.map((doc) => Rota.fromSnapshot(doc)).toList();

        final now = DateTime.now();
        const thresholdMinutes = 30;
        final upcoming = <_UpcomingTrip>[];
        for (final rota in rotas) {
          final next = _resolveNextStart(rota, now);
          if (next == null) continue;
          final diff = next.difference(now);
          if (diff.inMinutes >= 0 && diff.inMinutes <= thresholdMinutes) {
            upcoming.add(_UpcomingTrip(rota: rota, startTime: next));
          }
        }

        if (upcoming.isEmpty) {
          return const SizedBox.shrink();
        }

        upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));

        return Column(
          children: upcoming.map((item) {
            final diff = item.startTime.difference(now);
            final timeLabel = DateFormat('dd/MM HH:mm').format(item.startTime);
            final remaining = _formatRemaining(diff);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Card(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.alarm,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Início de viagem próximo',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.rota.nome,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Destino: ${item.rota.localDestinoNome}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Início previsto: $timeLabel ($remaining)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildWeatherAlertsCard(BuildContext context) {
    final weather = _weather;
    if (weather == null || _weatherLoading || _weatherError != null) {
      return const SizedBox.shrink();
    }

    final alerts = _detectWeatherAlerts(weather);
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Card(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alertas do clima',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...alerts.map((alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      children: [
                        Icon(alert.icon, color: alert.color),
                        const SizedBox(width: 8),
                        Expanded(child: Text(alert.message)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAirQualityCard(BuildContext context) {
    if (_airQualityLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Carregando qualidade do ar...'),
            ],
          ),
        ),
      );
    }
    if (_airQualityError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_airQualityError!),
        ),
      );
    }
    if (_airQuality == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Qualidade do ar indisponível no momento.'),
        ),
      );
    }

    final snapshot = _airQuality!;
    final aqiLabel = snapshot.aqi?.toString() ?? 'N/D';
    final category = snapshot.category ?? 'Sem categoria';
    final dominant = snapshot.dominantPollutant ?? 'Não informado';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.air,
              color: Theme.of(context).colorScheme.primary,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Qualidade do ar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Índice: $aqiLabel • $category',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Poluente dominante: $dominant',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollenCard(BuildContext context) {
    if (_pollenLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Carregando pólen...'),
            ],
          ),
        ),
      );
    }
    if (_pollenError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_pollenError!),
        ),
      );
    }
    if (_pollen == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Dados de pólen indisponíveis no momento.'),
        ),
      );
    }

    final snapshot = _pollen!;
    final category = snapshot.overallCategory ?? 'Sem categoria';
    final highTypes =
        snapshot.highTypes.isEmpty ? 'Nenhum tipo em alta' : snapshot.highTypes.join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.local_florist,
              color: Theme.of(context).colorScheme.tertiary,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pólen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Categoria geral: $category',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tipos em alta: $highTypes',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentalAlertsCard(BuildContext context) {
    if (_airQualityLoading || _pollenLoading) {
      return const SizedBox.shrink();
    }

    final alerts = _detectEnvironmentalAlerts();
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Card(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alertas ambientais',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...alerts.map((alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      children: [
                        Icon(alert.icon, color: alert.color),
                        const SizedBox(width: 8),
                        Expanded(child: Text(alert.message)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDriverNearCard(BuildContext context, UserRole role) {
    if (role != UserRole.aluno) {
      return const SizedBox.shrink();
    }
    final userId = _currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('alunos').doc(userId).get(),
      builder: (context, alunoSnapshot) {
        if (alunoSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final alunoData = alunoSnapshot.data?.data();
        final alunoGeo = alunoData?['localizacao'] as GeoPoint?;
        if (alunoGeo == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Informe sua localização no perfil para ver a aproximação do motorista.'),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('rotas')
              .where('status', isEqualTo: StatusRota.emAndamento.name)
              .where('listaAlunosIds', arrayContains: userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }
            if (snapshot.hasError) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Erro ao carregar rotas em andamento.'),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? const [];
            const maxDistanceMeters = 1000.0;
            final nearby = <_NearbyDriverInfo>[];

            for (final doc in docs) {
              final data = doc.data();
              final driverGeo = data['localizacaoAtualMotorista'] as GeoPoint?;
              if (driverGeo == null) continue;

              final distance = Geolocator.distanceBetween(
                alunoGeo.latitude,
                alunoGeo.longitude,
                driverGeo.latitude,
                driverGeo.longitude,
              );
              if (distance <= maxDistanceMeters) {
                final rota = Rota.fromSnapshot(doc);
                final lastUpdate = data['ultimaAtualizacaoMotorista'] as Timestamp?;
                nearby.add(_NearbyDriverInfo(
                  rota: rota,
                  distanceMeters: distance,
                  lastUpdate: lastUpdate?.toDate(),
                ));
              }
            }

            if (nearby.isEmpty) {
              return const SizedBox.shrink();
            }

            nearby.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

            return Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Column(
                children: nearby.map((info) {
                  final distancia = _formatDistance(info.distanceMeters);
                  final atualizado = info.lastUpdate == null
                      ? null
                      : DateFormat('HH:mm').format(info.lastUpdate!);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Card(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_bus,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Motorista próximo',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    info.rota.nome,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Distância: $distancia',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if (atualizado != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Atualizado às $atualizado',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  DateTime? _resolveNextStart(Rota rota, DateTime now) {
    final stored = rota.horaInicio?.toDate();
    if (stored != null && stored.isAfter(now)) {
      return stored;
    }
    return _calcularProximoHorario(rota, now);
  }

  DateTime? _calcularProximoHorario(Rota rota, DateTime now) {
    final time = _parseTime(rota.horarioInicioPrevisto);
    if (time == null) return null;

    final dias = rota.diasSemana;
    if (dias.isNotEmpty && dias.values.every((d) => !d)) {
      return null;
    }

    final todayWeekday = now.weekday;

    const dayMapping = {
      'Seg': DateTime.monday,
      'Ter': DateTime.tuesday,
      'Qua': DateTime.wednesday,
      'Qui': DateTime.thursday,
      'Sex': DateTime.friday,
      'Sab': DateTime.saturday,
      'Dom': DateTime.sunday,
    };

    for (var i = 0; i < 7; i++) {
      final weekday = (todayWeekday + i - 1) % 7 + 1;
      final dayKey =
          dayMapping.entries.firstWhere((e) => e.value == weekday).key;
      if (dias.isNotEmpty && dias[dayKey] != true) {
        continue;
      }
      final nextDay = DateTime(now.year, now.month, now.day + i);
      final nextOccurrence = DateTime(
        nextDay.year,
        nextDay.month,
        nextDay.day,
        time.hour,
        time.minute,
      );
      if (nextOccurrence.isAfter(now)) {
        return nextOccurrence;
      }
    }

    if (dias.isEmpty) {
      final candidate = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      return candidate.isAfter(now) ? candidate : null;
    }

    for (var i = 0; i < 7; i++) {
      final weekday = (todayWeekday + i - 1) % 7 + 1;
      final dayKey =
          dayMapping.entries.firstWhere((e) => e.value == weekday).key;
      if (dias[dayKey] == true) {
        final nextDay = DateTime(now.year, now.month, now.day + i + 7);
        return DateTime(
          nextDay.year,
          nextDay.month,
          nextDay.day,
          time.hour,
          time.minute,
        );
      }
    }

    return null;
  }

  TimeOfDay? _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatRemaining(Duration diff) {
    if (diff.isNegative) return 'já iniciado';
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) {
      return 'em ${hours}h ${minutes}m';
    }
    return 'em $minutes min';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  List<_WeatherAlert> _detectWeatherAlerts(_WeatherSnapshot weather) {
    final alerts = <_WeatherAlert>[];
    if (weather.temperatureC >= 30) {
      alerts.add(const _WeatherAlert(
        message: 'Calor intenso. Hidrate-se antes da viagem.',
        icon: Icons.thermostat,
        color: Colors.deepOrange,
      ));
    }
    if (weather.temperatureC <= 15) {
      alerts.add(const _WeatherAlert(
        message: 'Frio intenso. Leve um agasalho para a viagem.',
        icon: Icons.ac_unit,
        color: Colors.lightBlue,
      ));
    }

    final description = weather.description.toLowerCase();
    final rainTokens = [
      'rain',
      'chuva',
      'chuvis',
      'garoa',
      'shower',
      'drizzle',
      'storm',
      'tempest',
      'trovo',
    ];
    if (rainTokens.any((token) => description.contains(token))) {
      alerts.add(const _WeatherAlert(
        message: 'Possibilidade de chuva. Leve capa ou guarda-chuva.',
        icon: Icons.water_drop,
        color: Colors.blue,
      ));
    }

    return alerts;
  }

  List<_EnvironmentalAlert> _detectEnvironmentalAlerts() {
    final alerts = <_EnvironmentalAlert>[];

    final air = _airQuality;
    if (air != null && _isAirQualityConcern(air)) {
      final aqiLabel = air.aqi?.toString() ?? 'N/D';
      final category = air.category ?? 'qualidade desconhecida';
      final pollutant =
          air.dominantPollutant == null ? '' : ' Poluente: ${air.dominantPollutant}.';
      alerts.add(_EnvironmentalAlert(
        message:
            'Qualidade do ar em atenção ($category, AQI $aqiLabel).$pollutant',
        icon: Icons.air,
        color: Colors.deepOrange,
      ));
    }

    final pollen = _pollen;
    if (pollen != null && _isPollenConcern(pollen)) {
      final category = pollen.overallCategory ?? 'nível elevado';
      final types = pollen.highTypes.isEmpty
          ? ''
          : ' Tipos em alta: ${pollen.highTypes.join(', ')}.';
      alerts.add(_EnvironmentalAlert(
        message: 'Pólen em atenção ($category).$types',
        icon: Icons.local_florist,
        color: Colors.orange,
      ));
    }

    return alerts;
  }

  bool _isAirQualityConcern(AirQualitySnapshot snapshot) {
    final aqi = snapshot.aqi;
    if (aqi != null && aqi >= 101) return true;
    final category = snapshot.category?.toLowerCase() ?? '';
    if (category.isEmpty) return false;
    const tokens = [
      'unhealthy',
      'poor',
      'ruim',
      'muito',
      'alto',
      'elev',
      'hazard',
      'insal',
    ];
    return tokens.any(category.contains);
  }

  bool _isPollenConcern(PollenSnapshot snapshot) {
    if (snapshot.highTypes.isNotEmpty) return true;
    final category = snapshot.overallCategory?.toLowerCase() ?? '';
    if (category.isEmpty) return false;
    const tokens = ['high', 'alto', 'elev', 'muito', 'very'];
    return tokens.any(category.contains);
  }

  Future<void> _carregarClima(UserRole role) async {
    final userId = _currentUser?.uid;
    if (userId == null) return;
    final apiKey = googleApiKey;
    if (apiKey.isEmpty) {
      if (!mounted) return;
      setState(() {
        _weatherError = 'Chave de clima não configurada.';
      });
      return;
    }

    setState(() {
      _weatherLoading = true;
      _weatherError = null;
    });

    try {
      final location =
          await (_userLocationFuture ??= _buscarLocalizacaoUsuario(role));
      if (location == null) {
        throw Exception('Localização não informada no perfil.');
      }

      final uri = Uri.https('weather.googleapis.com', '/v1/currentConditions:lookup', {
        'key': apiKey,
        'location.latitude': location.geo.latitude.toString(),
        'location.longitude': location.geo.longitude.toString(),
        'languageCode': 'pt-BR',
        'unitsSystem': 'METRIC',
      });
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar clima (${response.statusCode}).');
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final temperature = payload['temperature'] as Map<String, dynamic>?;
      final weatherCondition =
          payload['weatherCondition'] as Map<String, dynamic>?;
      if (temperature == null || weatherCondition == null) {
        throw Exception('Resposta de clima inválida.');
      }
      final descriptionMap =
          weatherCondition['description'] as Map<String, dynamic>?;
      final description = descriptionMap?['text'] as String? ?? 'Clima atual';
      final iconBase = weatherCondition['iconBaseUri'] as String?;
      final iconUrl = iconBase == null ? null : '$iconBase.png';
      final tempValue = (temperature['degrees'] as num?)?.toDouble() ?? 0;

      if (!mounted) return;
      setState(() {
        _weather = _WeatherSnapshot(
          temperatureC: tempValue,
          description: description,
          iconUrl: iconUrl,
          locationName: location.locationName,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weatherError = 'Não foi possível carregar o clima: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _weatherLoading = false;
        });
      }
    }
  }

  Future<void> _carregarQualidadeAr(UserRole role) async {
    final apiKey = googleApiKey;
    if (apiKey.isEmpty) {
      if (!mounted) return;
      setState(() {
        _airQualityError = 'Chave de qualidade do ar não configurada.';
      });
      return;
    }

    setState(() {
      _airQualityLoading = true;
      _airQualityError = null;
    });

    try {
      final location =
          await (_userLocationFuture ??= _buscarLocalizacaoUsuario(role));
      if (location == null) {
        throw Exception('Localização não informada no perfil.');
      }

      final service = AirQualityService(apiKey: apiKey);
      final snapshot = await service.fetchCurrent(
        latitude: location.geo.latitude,
        longitude: location.geo.longitude,
      );
      if (!mounted) return;
      setState(() {
        _airQuality = snapshot;
        if (snapshot == null) {
          _airQualityError = 'Qualidade do ar indisponível no momento.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _airQualityError = 'Não foi possível carregar a qualidade do ar: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _airQualityLoading = false;
        });
      }
    }
  }

  Future<void> _carregarPolem(UserRole role) async {
    final apiKey = googleApiKey;
    if (apiKey.isEmpty) {
      if (!mounted) return;
      setState(() {
        _pollenError = 'Chave de pólen não configurada.';
      });
      return;
    }

    setState(() {
      _pollenLoading = true;
      _pollenError = null;
    });

    try {
      final location =
          await (_userLocationFuture ??= _buscarLocalizacaoUsuario(role));
      if (location == null) {
        throw Exception('Localização não informada no perfil.');
      }

      final service = PollenService(apiKey: apiKey);
      final snapshot = await service.fetchForecast(
        latitude: location.geo.latitude,
        longitude: location.geo.longitude,
      );

      if (!mounted) return;
      setState(() {
        _pollen = snapshot;
        if (snapshot == null) {
          _pollenError = 'Dados de pólen indisponíveis no momento.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pollenError = 'Não foi possível carregar o pólen: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _pollenLoading = false;
        });
      }
    }
  }

  String? _extractCityFromAddress(String address) {
    final parts = address.split(',');
    for (final raw in parts.reversed) {
      var part = raw.trim();
      if (part.isEmpty) continue;
      final lower = part.toLowerCase();
      if (lower.contains('brasil')) continue;
      if (part.contains('-')) {
        part = part.split('-').first.trim();
      }
      final cleaned = part.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ ]'), '').trim();
      if (cleaned.length >= 3) {
        return cleaned;
      }
    }
    return null;
  }
}

class _WeatherSnapshot {
  final double temperatureC;
  final String description;
  final String? iconUrl;
  final String? locationName;

  const _WeatherSnapshot({
    required this.temperatureC,
    required this.description,
    this.iconUrl,
    this.locationName,
  });
}

class _UserLocation {
  final GeoPoint geo;
  final String? locationName;

  const _UserLocation({
    required this.geo,
    this.locationName,
  });
}

class _WeatherAlert {
  final String message;
  final IconData icon;
  final Color color;

  const _WeatherAlert({
    required this.message,
    required this.icon,
    required this.color,
  });
}

class _EnvironmentalAlert {
  final String message;
  final IconData icon;
  final Color color;

  const _EnvironmentalAlert({
    required this.message,
    required this.icon,
    required this.color,
  });
}

class _UpcomingTrip {
  final Rota rota;
  final DateTime startTime;

  const _UpcomingTrip({
    required this.rota,
    required this.startTime,
  });
}

class _NearbyDriverInfo {
  final Rota rota;
  final double distanceMeters;
  final DateTime? lastUpdate;

  const _NearbyDriverInfo({
    required this.rota,
    required this.distanceMeters,
    this.lastUpdate,
  });
}
