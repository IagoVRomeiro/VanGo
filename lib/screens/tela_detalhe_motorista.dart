// lib/screens/tela_detalhe_motorista.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vango/models/motorista.dart';
import 'package:vango/models/van.dart'; // 🔹 IMPORTAR O MODELO VAN

// 🔹 1. MUDAR PARA STATEFULWIDGET
class TelaDetalheMotorista extends StatefulWidget {
  final Motorista motorista;
  // 🔹 2. RECEBER A FOTO DO MOTORISTA PELO CONSTRUTOR
  final String? fotoUrl; 

  const TelaDetalheMotorista({
    super.key, 
    required this.motorista, 
    this.fotoUrl, // ⬅️ Vindo da tela de busca
  });

  @override
  State<TelaDetalheMotorista> createState() => _TelaDetalheMotoristaState();
}

class _TelaDetalheMotoristaState extends State<TelaDetalheMotorista> {
  
  Van? _van;
  bool _isLoadingVan = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosDaVan();
  }

  // 🔹 3. FUNÇÃO PARA BUSCAR A VAN ASSOCIADA
  Future<void> _carregarDadosDaVan() async {
    if (widget.motorista.vanId == null || widget.motorista.vanId!.isEmpty) {
      if (mounted) setState(() => _isLoadingVan = false);
      return; // Motorista não tem van
    }
    
    try {
      final vanDoc = await FirebaseFirestore.instance
          .collection('vans')
          .doc(widget.motorista.vanId)
          .get();
          
      if (vanDoc.exists && mounted) {
        setState(() {
          _van = Van.fromSnapshot(vanDoc);
          _isLoadingVan = false;
        });
      } else {
         if (mounted) setState(() => _isLoadingVan = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingVan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados da van: $e')),
      );
    }
  }


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
        'motoristaId': widget.motorista.id, // ⬅️ Usar widget.motorista
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
        title: Text(widget.motorista.nome),
        backgroundColor: Colors.amber,
        foregroundColor: const Color(0xFF2d2d2d), // Texto escuro
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🔹 4. FOTO DA VAN (NÃO DO MOTORISTA)
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: _isLoadingVan
                  ? const Center(child: CircularProgressIndicator())
                  : _van?.vanFotoUrl != null
                      ? Image.network(
                          _van!.vanFotoUrl!,
                          fit: BoxFit.cover,
                        )
                      : Image.asset( // Placeholder da VAN
                          'assets/images/van_placeholder.png', 
                          fit: BoxFit.cover,
                        ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 🔹 5. FOTO DO MOTORISTA (EM CÍRCULO)
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: widget.fotoUrl != null
                        ? NetworkImage(widget.fotoUrl!)
                        : const AssetImage('assets/images/user_placeholder.png')
                            as ImageProvider,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.motorista.nome,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      'Avaliação: ${widget.motorista.avaliacao.toStringAsFixed(1)} ★',
                      style: const TextStyle(color: Colors.black87),
                    ),
                    backgroundColor: Colors.amber.shade200,
                  ),
                  const Divider(height: 40),
                  
                  // 🔹 6. DADOS DA VAN (EM VEZ DE 'motorista.veiculo')
                  _buildInfoRow(Icons.directions_car, 'Veículo',
                      _isLoadingVan ? 'Carregando...' : '${_van?.marca ?? ''} ${_van?.modelo ?? 'Não informado'}'),
                  _buildInfoRow(Icons.pin_outlined, 'Placa',
                      _isLoadingVan ? '...' : _van?.placa ?? 'Não informada'),
                  _buildInfoRow(Icons.group, 'Capacidade',
                      _isLoadingVan ? '...' : '${_van?.capacidade.toString() ?? '?'} passageiros'),
                      
                  // Telefone (idealmente, só mostrar após aceite do contrato)
                  _buildInfoRow(Icons.phone, 'Telefone', widget.motorista.telefone.isNotEmpty ? widget.motorista.telefone : 'Não informado'),
                  
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () => _solicitarVinculo(context),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Solicitar Contato'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: const Color(0xFF2d2d2d),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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