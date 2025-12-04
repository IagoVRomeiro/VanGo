import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/neon_app_bar.dart';
import 'package:vango/l10n/app_localizations.dart';

class TelaAvaliacoesMotorista extends StatelessWidget {
  final String motoristaId;
  final String motoristaNome;

  const TelaAvaliacoesMotorista({
    super.key,
    required this.motoristaId,
    required this.motoristaNome,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> _avaliacoesStream() {
    return FirebaseFirestore.instance
        .collection('motoristas')
        .doc(motoristaId)
        .collection('avaliacoes')
        .orderBy('atualizadoEm', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: NeonAppBar(
        title: l10n.avaliacoesTitle,
        subtitle: motoristaNome,
        showMenuButton: false,
        showBackButton: true,
        showNotificationsButton: false,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _avaliacoesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(l10n.errorLoadingRatings('${snapshot.error}')),
              ),
            );
          }

          final avaliacoes = snapshot.data?.docs ?? [];
          if (avaliacoes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(l10n.noRatings),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: avaliacoes.length,
            itemBuilder: (context, index) {
              final data = avaliacoes[index].data();
              final nota = (data['nota'] as num?)?.toDouble() ?? 0;
              final comentario = (data['comentario'] as String?)?.trim();
              final timestamp = data['atualizadoEm'] as Timestamp?;
              final alunoId = data['alunoId'] as String?;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            nota.toStringAsFixed(1),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (timestamp != null)
                            Text(
                              _formatarData(timestamp),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                      if (comentario != null && comentario.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          comentario,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        alunoId != null && alunoId.isNotEmpty
                            ? l10n.studentLabel(_formatarAlunoId(alunoId))
                            : l10n.studentUnknown,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _formatarData(Timestamp timestamp) {
    final dt = timestamp.toDate();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  static String _formatarAlunoId(String alunoId) {
    if (alunoId.length <= 6) return alunoId;
    return '${alunoId.substring(0, 3)}...${alunoId.substring(alunoId.length - 3)}';
  }
}
