// lib/screens/tela_busca_motorista.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vango/models/motorista.dart';

class TelaBuscaMotorista extends StatefulWidget {
  const TelaBuscaMotorista({super.key});

  @override
  State<TelaBuscaMotorista> createState() => _TelaBuscaMotoristaState();
}

class _TelaBuscaMotoristaState extends State<TelaBuscaMotorista> {
  List<Motorista> _todosMotoristas = [];
  List<Motorista> _motoristasFiltrados = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarMotoristas();
    _searchController.addListener(_filtrarMotoristas);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarMotoristas() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('motoristas').get();
      final motoristas = snapshot.docs.map((doc) => Motorista.fromMap(doc.data())).toList();
      setState(() {
        _todosMotoristas = motoristas;
        _motoristasFiltrados = motoristas;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar motoristas: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filtrarMotoristas() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _motoristasFiltrados = _todosMotoristas.where((motorista) {
        return motorista.nome.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Procurar Motorista'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar por nome',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _motoristasFiltrados.isEmpty
                    ? const Center(child: Text('Nenhum motorista encontrado.'))
                    : ListView.builder(
                        itemCount: _motoristasFiltrados.length,
                        itemBuilder: (context, index) {
                          final motorista = _motoristasFiltrados[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey.shade300,
                                child: Text(motorista.nome.isNotEmpty ? motorista.nome[0] : '?'),
                              ),
                              title: Text(motorista.nome),
                              subtitle: Text('Avaliação: ${motorista.avaliacao.toStringAsFixed(1)} ★'),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () {
                                // TODO: Navegar para a tela de detalhes do motorista
                                debugPrint('Selecionou o motorista: ${motorista.nome}');
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}