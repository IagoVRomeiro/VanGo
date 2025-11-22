// lib/screens/tela_detalhe_motorista.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vango/models/motorista.dart';
import 'package:vango/models/van.dart'; // 🔹 IMPORTAR O MODELO VAN

import 'package:vango/screens/tela_chat.dart';

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

  Future<void> _carregarDadosDaVan() async {
    if (widget.motorista.vanId == null || widget.motorista.vanId!.isEmpty) {
      if (mounted) setState(() => _isLoadingVan = false);
      return;
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
        'motoristaId': widget.motorista.id,
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

  Future<void> _iniciarChatDeInquerito() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você precisa estar logado para enviar uma mensagem.')),
      );
      return;
    }

    final motoristaId = widget.motorista.id;
    final alunoId = currentUser.uid;

    try {
      // Procura por um chat existente (de qualquer tipo)
      final query = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: alunoId)
          .get();
      
      String? existingChatId;
      for (var doc in query.docs) {
        final participants = List<String>.from(doc.data()['participants']);
        if (participants.contains(motoristaId)) {
          existingChatId = doc.id;
          break;
        }
      }

      String chatId;
      if (existingChatId != null) {
        chatId = existingChatId;
      } else {
        // Cria um novo chat com status 'inquiry'
        final newChatDoc = await FirebaseFirestore.instance.collection('chats').add({
          'participants': [alunoId, motoristaId],
          'status': 'inquiry',
          'lastMessage': {
            'text': '...',
            'senderId': '',
            'timestamp': FieldValue.serverTimestamp(),
          }
        });
        chatId = newChatDoc.id;
      }

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
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro ao iniciar chat: $e'), backgroundColor: Colors.red),
            );
        }
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
                  
                  _buildInfoRow(Icons.directions_car, 'Veículo',
                      _isLoadingVan ? 'Carregando...' : '${_van?.marca ?? ''} ${_van?.modelo ?? 'Não informado'}'),
                  _buildInfoRow(Icons.pin_outlined, 'Placa',
                      _isLoadingVan ? '...' : _van?.placa ?? 'Não informada'),
                  _buildInfoRow(Icons.group, 'Capacidade',
                      _isLoadingVan ? '...' : '${_van?.capacidade.toString() ?? '?'} passageiros'),
                      
                  _buildInfoRow(Icons.phone, 'Telefone', widget.motorista.telefone.isNotEmpty ? widget.motorista.telefone : 'Não informado'),
                  
                ],
              ),
            ),
          ],
        ),
      ),
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _iniciarChatDeInquerito,
                  icon: const Icon(Icons.message_outlined),
                  label: const Text('Mensagem'),
                  style: OutlinedButton.styleFrom(
                     padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _solicitarVinculo(context),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Solicitar Vínculo'),
                   style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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