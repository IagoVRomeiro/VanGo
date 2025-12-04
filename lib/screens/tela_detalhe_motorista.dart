// As imagens desta tela assumem que a extensão "Resize Images" do Firebase
// gera versões com o sufixo "_400x400".

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:vango/models/motorista.dart';
import 'package:vango/models/rota.dart';
import 'package:vango/screens/tela_chat.dart';
import 'package:vango/services/chat_service.dart';
import 'package:vango/services/image_service.dart';
import 'package:vango/services/functions_service.dart';
import '../widgets/neon_app_bar.dart';
import 'tela_notificacoes.dart';
import 'tela_avaliacoes_motorista.dart';

class TelaDetalheMotorista extends StatefulWidget {
  final Motorista motorista;
  final String? fotoUrl; 
  final String nome;
  final String? telefone;

  const TelaDetalheMotorista({
    super.key, 
    required this.motorista, 
    this.fotoUrl,
    required this.nome,
    this.telefone,
  });

  @override
  State<TelaDetalheMotorista> createState() => _TelaDetalheMotoristaState();
}

class _TelaDetalheMotoristaState extends State<TelaDetalheMotorista> {
  List<Rota> _rotas = [];
  bool _isLoadingRotas = true;
  double _avaliacaoAtual = 0;
  int _avaliacoesQtd = 0;

  @override
  void initState() {
    super.initState();
    _avaliacaoAtual = widget.motorista.avaliacao;
    _carregarRotas();
    _carregarResumoAvaliacoes();
  }

  Future<void> _carregarRotas() async {
    try {
      final rotasSnapshot = await FirebaseFirestore.instance
          .collection('rotas')
          .where('motoristaId', isEqualTo: widget.motorista.id)
          .get();

      if (mounted) {
        setState(() {
          _rotas =
              rotasSnapshot.docs.map((doc) => Rota.fromSnapshot(doc)).toList();
          _isLoadingRotas = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRotas = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar rotas: $e')),
      );
    }
  }

  Future<void> _carregarResumoAvaliacoes() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('motoristas')
          .doc(widget.motorista.id)
          .collection('avaliacoes')
          .get();
      if (!mounted) return;
      setState(() {
        _avaliacoesQtd = snapshot.docs.length;
      });
    } catch (_) {
    }
  }

  Future<void> _solicitarVinculo(BuildContext context) async {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Você precisa estar logado para solicitar.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('contratos').add({
        'motoristaId': widget.motorista.id,
        'alunoId': currentUser.uid,
        'idResponsavel': currentUser.uid,
        'status': 'pendente',
        'dataSolicitacao': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Solicitação enviada com sucesso!'),
            backgroundColor: theme.colorScheme.primary),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao enviar solicitação: $e'),
            backgroundColor: theme.colorScheme.error),
      );
    }
  }

  Future<void> _iniciarChatDeInquerito() async {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Você precisa estar logado para enviar uma mensagem.')),
      );
      return;
    }

    final motoristaId = widget.motorista.id;
    final alunoId = currentUser.uid;

    try {
      final alunoDoc = await FirebaseFirestore.instance
          .collection('alunos')
          .doc(alunoId)
          .get();
      final alunoData = alunoDoc.data();
      final estaVinculado =
          alunoData != null && alunoData['motoristaId'] == motoristaId;

      final chatId = await ChatService.ensureChat(
        alunoId: alunoId,
        motoristaId: motoristaId,
        activate: estaVinculado,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TelaChat(
              chatId: chatId,
              recipientId: motoristaId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar chat: $e'), backgroundColor: theme.colorScheme.error),
        );
      }
    }
  }

  Future<void> _avaliarMotorista() async {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Faça login para avaliar o motorista.'),
            backgroundColor: theme.colorScheme.error),
      );
      return;
    }

    if (currentUser.uid == widget.motorista.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Você não pode avaliar a si mesmo.'),
            backgroundColor: theme.colorScheme.secondary),
      );
      return;
    }

    if (!mounted) return;
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AvaliacaoMotoristaDialog(),
    );

    if (!mounted) return;
    if (resultado == null) return;

    final nota = (resultado['nota'] as double?) ?? 5;
    final comentario = resultado['comentario'] as String? ?? '';

    try {
      final result = await FunctionsService.instance.call<Map<String, dynamic>>(
        'avaliarMotorista',
        data: {
        'motoristaId': widget.motorista.id,
        'nota': nota,
        'comentario': comentario,
        },
      );

      final data = result.data;
      final media = (data['media'] as num?)?.toDouble() ?? nota;
      final quantidade = data['quantidade'] as int? ?? _avaliacoesQtd;

      if (!mounted) return;
      setState(() {
        _avaliacaoAtual = media;
        _avaliacoesQtd = quantidade;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Avaliação registrada!'),
          backgroundColor: theme.colorScheme.primary,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Erro ao salvar avaliação.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar avaliação: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _abrirTelaAvaliacoes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaAvaliacoesMotorista(
          motoristaId: widget.motorista.id,
          motoristaNome: widget.nome,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Prioriza a foto original para evitar dependência da extensão de resize.
    final fotoUrl = widget.fotoUrl;

    return Scaffold(
      appBar: NeonAppBar(
        title: widget.nome,
        showMenuButton: false,
        showBackButton: true,
        onNotificationsPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TelaNotificacoes()),
          );
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipOval(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: fotoUrl != null && fotoUrl.isNotEmpty
                      ? Image.network(
                          fotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset('assets/iconSemFundo.png', fit: BoxFit.cover),
                        )
                      : Image.asset('assets/iconSemFundo.png', fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                widget.nome,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Chip(
                label: Text(
                  'Avaliação: ${_avaliacaoAtual.toStringAsFixed(1)} ★ ${_avaliacoesQtd > 0 ? '($_avaliacoesQtd)' : ''}',
                ),
                avatar: Icon(Icons.star, color: theme.colorScheme.primary),
                backgroundColor: theme.colorScheme.surfaceVariant,
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: _abrirTelaAvaliacoes,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Ver avaliações'),
              ),
            ),
            const Divider(height: 32),
            _buildInfoCard(),
            const SizedBox(height: 24),
            Text(
              'Rotas Disponíveis',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildRotasList(),
          ],
        ),
      ),
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _iniciarChatDeInquerito,
                  icon: const Icon(Icons.message_outlined),
                  label: const Text('Mensagem'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _solicitarVinculo(context),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Solicitar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded( 
                child: ElevatedButton.icon(
                  onPressed: _avaliarMotorista,
                  icon: const Icon(Icons.star_rate_rounded),
                  label: const Text('Avaliar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow(Icons.phone, 'Telefone', widget.telefone != null && widget.telefone!.isNotEmpty ? widget.telefone! : 'Não informado'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildRotasList() {
    if (_isLoadingRotas) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rotas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text('Nenhuma rota cadastrada.'),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _rotas.length,
      itemBuilder: (context, index) {
        final rota = _rotas[index];
        final dias = rota.diasSemana.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key.substring(0, 3))
            .join(', ');
        final horario = '${rota.horarioInicioPrevisto} - ${rota.horarioFimPrevisto}';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.route),
            ),
            title: Text(rota.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${rota.localDestinoNome}\n$dias | $horario'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
            },
          ),
        );
      },
    );
  }
}

class _AvaliacaoMotoristaDialog extends StatefulWidget {
  const _AvaliacaoMotoristaDialog();

  @override
  State<_AvaliacaoMotoristaDialog> createState() => _AvaliacaoMotoristaDialogState();
}

// Dialog stateful para manter o estado da nota/comentario e descartar o controller no dispose.
class _AvaliacaoMotoristaDialogState extends State<_AvaliacaoMotoristaDialog> {
  final TextEditingController _comentarioController = TextEditingController();
  double _notaSelecionada = 5;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Avaliar motorista'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Nota: ${_notaSelecionada.toStringAsFixed(1)}'),
          Slider(
            min: 1,
            max: 5,
            divisions: 8,
            label: _notaSelecionada.toStringAsFixed(1),
            value: _notaSelecionada,
            onChanged: (value) {
              setState(() {
                _notaSelecionada = value;
              });
            },
            activeColor: theme.colorScheme.primary,
          ),
          TextField(
            controller: _comentarioController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comentário (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'nota': _notaSelecionada,
              'comentario': _comentarioController.text.trim(),
            });
          },
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
