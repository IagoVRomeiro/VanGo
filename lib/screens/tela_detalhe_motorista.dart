import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vango/models/motorista.dart';

class TelaDetalheMotorista extends StatelessWidget {
  final Motorista motorista;

  const TelaDetalheMotorista({super.key, required this.motorista});

  Future<void> _solicitarVinculo(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Você precisa estar logado para solicitar.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('contratos').add({
        'motoristaId': motorista.id,
        'alunoId': currentUser.uid,
        'idResponsavel': currentUser.uid,
        'status': 'pendente',
        'dataSolicitacao': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Solicitação enviada com sucesso!'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao enviar solicitação: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(motorista.nome),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: motorista.fotoUrl != null
                      ? NetworkImage(motorista.fotoUrl!)
                      : const AssetImage('assets/images/user_placeholder.png')
                          as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    motorista.nome,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // ✅ CORRIGIDO: Removida a linha que exibia a experiência
                  Chip(
                    label: Text(
                      'Avaliação: ${motorista.avaliacao.toStringAsFixed(1)} ★',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.amber,
                  ),
                  const Divider(height: 40),
                  _buildInfoRow(Icons.directions_car, 'Veículo',
                      motorista.veiculo ?? 'Não informado'),
                  _buildInfoRow(
                      Icons.pin, 'Placa', motorista.placa ?? 'Não informada'),
                  _buildInfoRow(Icons.phone, 'Telefone', motorista.telefone),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () => _solicitarVinculo(context),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Solicitar Contato'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
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
          Icon(icon, color: Colors.grey.shade500),
          const SizedBox(width: 16),
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

