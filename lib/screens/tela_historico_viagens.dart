import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vango/models/rota.dart';
import '../widgets/neon_app_bar.dart';

class TelaHistoricoViagens extends StatelessWidget {
  final bool showAppBar;
  final bool isDriver;

  const TelaHistoricoViagens({
    super.key,
    this.showAppBar = true,
    this.isDriver = true,
  });
  const TelaHistoricoViagens.aluno({super.key, this.showAppBar = true})
      : isDriver = false;
  const TelaHistoricoViagens.motorista({super.key, this.showAppBar = true})
      : isDriver = true;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        appBar: showAppBar
            ? const NeonAppBar(
                title: 'Histórico de Viagens',
                showMenuButton: false,
                showBackButton: true,
                showNotificationsButton: false,
              )
            : null,
        body: const Center(
          child: Text('Faça login para ver o histórico.'),
        ),
      );
    }

    final baseQuery = FirebaseFirestore.instance
        .collection('rotas')
        .where('status', whereIn: [
      StatusRota.concluida.name,
      StatusRota.cancelada.name,
    ]);
    final query = isDriver
        ? baseQuery.where('motoristaId', isEqualTo: userId)
        : baseQuery.where('listaAlunosIds', arrayContains: userId);

    final body = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text('Não foi possível carregar o histórico.'),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('Nenhuma viagem finalizada no momento.'),
            ),
          );
        }

        final rotas = docs
            .map((doc) => Rota.fromSnapshot(doc))
            .toList()
          ..sort((a, b) {
            final aTime = a.horaInicio ?? a.criadoEm;
            final bTime = b.horaInicio ?? b.criadoEm;
            return (bTime?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(aTime?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0));
          });

        return ListView.separated(
          padding: const EdgeInsets.all(16.0),
          itemCount: rotas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final rota = rotas[index];
            final timestamp = rota.horaInicio ?? rota.criadoEm;
            final dateLabel = timestamp == null
                ? 'Data não informada'
                : DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
            final statusLabel =
                rota.status == StatusRota.concluida ? 'Concluída' : 'Cancelada';

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.history, color: Colors.white),
                ),
                title: Text(rota.nome),
                subtitle: Text(
                  [
                    rota.localDestinoNome,
                    'Alunos: ${rota.listaAlunosIds.length}',
                    'Horário: ${rota.horarioInicioPrevisto} - ${rota.horarioFimPrevisto}',
                  ].join('\n'),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: rota.status == StatusRota.concluida
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!showAppBar) return body;

    return Scaffold(
      appBar: const NeonAppBar(
        title: 'Histórico de Viagens',
        showMenuButton: false,
        showBackButton: true,
        showNotificationsButton: false,
      ),
      body: body,
    );
  }
}
