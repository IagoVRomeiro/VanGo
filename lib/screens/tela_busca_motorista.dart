// lib/screens/tela_busca_motorista.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vango/models/motorista.dart';
import 'package:vango/screens/tela_detalhe_motorista.dart';

class TelaBuscaMotorista extends StatefulWidget {
  const TelaBuscaMotorista({super.key});

  @override
  State<TelaBuscaMotorista> createState() => _TelaBuscaMotoristaState();
}

class _TelaBuscaMotoristaState extends State<TelaBuscaMotorista> {
  List<Motorista> _todosMotoristas = [];
  List<Motorista> _motoristasFiltrados = [];
  // 🔹 ADICIONADO: Map para guardar as fotos
  Map<String, String?> _fotosMotoristas = {};
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
      // 1. Busca todos os motoristas
      final motoristaSnapshot =
          await FirebaseFirestore.instance.collection('motoristas').get();
      final motoristas = motoristaSnapshot.docs
          .map((doc) => Motorista.fromMap(doc.id, doc.data()))
          .toList();

      if (motoristas.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Pega os IDs de todos os motoristas
      final motoristaIds = motoristas.map((m) => m.id).toList();

      // 3. Busca as fotos correspondentes na coleção 'users'
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: motoristaIds)
          .get();

      // 4. Cria um Map de <motoristaId, fotoUrl>
      final Map<String, String?> fotos = {
        for (var doc in userSnapshot.docs)
          doc.id: doc.data()['fotoUrl'] as String?
      };

      if (mounted) {
        setState(() {
          _todosMotoristas = motoristas;
          _motoristasFiltrados = motoristas;
          _fotosMotoristas = fotos; // 🔹 Salva o Map de fotos
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao carregar motoristas: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filtrarMotoristas() {
    final query = _searchController.text.toLowerCase().trim();
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
        backgroundColor: Colors.amber, // Cor do Aluno
        foregroundColor: const Color(0xFF2d2d2d), // Texto escuro
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar por nome',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                          // 🔹 CORREÇÃO: Pega a foto do Map
                          final fotoUrl = _fotosMotoristas[motorista.id];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                // 🔹 CORREÇÃO: Usa a variável 'fotoUrl'
                                backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty
                                    ? NetworkImage(fotoUrl)
                                    : const AssetImage(
                                            'assets/images/user_placeholder.png')
                                        as ImageProvider,
                                radius: 25,
                              ),
                              title: Text(motorista.nome,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  'Avaliação: ${motorista.avaliacao.toStringAsFixed(1)} ★'),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    // 🔹 CORREÇÃO: Passa a foto para a tela de detalhe
                                    builder: (context) => TelaDetalheMotorista(
                                      motorista: motorista,
                                      fotoUrl: fotoUrl,
                                    ),
                                  ),
                                );
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
