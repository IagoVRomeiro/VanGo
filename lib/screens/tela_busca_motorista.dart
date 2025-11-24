// lib/screens/tela_busca_motorista.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vango/models/motorista.dart';
import 'package:vango/models/rota.dart'; // <--- ADDED THIS IMPORT
import 'package:vango/screens/tela_aluno.dart';
import 'package:vango/screens/tela_lista_chats.dart';
import 'package:vango/screens/tela_detalhe_motorista.dart';
import 'package:vango/screens/tela_perfil.dart';

class TelaBuscaMotorista extends StatefulWidget {
  const TelaBuscaMotorista({super.key});

  @override
  State<TelaBuscaMotorista> createState() => _TelaBuscaMotoristaState();
}

class _TelaBuscaMotoristaState extends State<TelaBuscaMotorista> {
  List<Motorista> _todosMotoristas = [];
  List<Rota> _todasRotas = [];
  List<Motorista> _motoristasFiltrados = [];
  Motorista? _motoristaVinculado;
  Map<String, String?> _fotosMotoristas = {};
  String? _fotoMotoristaVinculado;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _faculdadeController = TextEditingController();
  int _selectedIndex = 2; // Inicia no ícone de busca

  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser != null) {
      _carregarMotoristas();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
    _searchController.addListener(_filtrarMotoristas);
    _faculdadeController.addListener(_filtrarMotoristas);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _faculdadeController.dispose();
    super.dispose();
  }

  Future<void> _carregarMotoristas() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? motoristaVinculadoId;

      if (user != null) {
        final alunoDoc = await FirebaseFirestore.instance
            .collection('alunos')
            .doc(user.uid)
            .get();
        if (alunoDoc.exists) {
          motoristaVinculadoId = alunoDoc.data()?['motoristaId'] as String?;
        }
      }

      final results = await Future.wait([
        FirebaseFirestore.instance.collection('motoristas').get(),
        FirebaseFirestore.instance.collection('rotas').get(),
      ]);

      final motoristaSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final rotaSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;

      final motoristas = motoristaSnapshot.docs
          .map((doc) => Motorista.fromMap(doc.id, doc.data()))
          .toList();
      
      final rotas = rotaSnapshot.docs
          .map((doc) => Rota.fromSnapshot(doc))
          .toList();

      if (motoristas.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      Motorista? motoristaVinculado;
      if (motoristaVinculadoId != null) {
        try {
          motoristaVinculado = motoristas.firstWhere((m) => m.id == motoristaVinculadoId);
        } catch (e) {
          motoristaVinculado = null;
        }
      }

      final motoristaIds = motoristas.map((m) => m.id).toList();

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: motoristaIds)
          .get();

      final Map<String, String?> fotos = {
        for (var doc in userSnapshot.docs)
          doc.id: doc.data()['fotoUrl'] as String?
      };

      String? fotoMotoristaVinculado;
      if (motoristaVinculado != null) {
        fotoMotoristaVinculado = fotos[motoristaVinculado.id];
        motoristas.removeWhere((m) => m.id == motoristaVinculado!.id);
      }

      if (mounted) {
        setState(() {
          _motoristaVinculado = motoristaVinculado;
          _fotoMotoristaVinculado = fotoMotoristaVinculado;
          _todosMotoristas = motoristas;
          _motoristasFiltrados = motoristas;
          _todasRotas = rotas;
          _fotosMotoristas = fotos;
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
    final queryNome = _searchController.text.toLowerCase().trim();
    final queryFaculdade = _faculdadeController.text.toLowerCase().trim();
    
    setState(() {
      _motoristasFiltrados = _todosMotoristas.where((motorista) {
        final nomeMatch = motorista.nome.toLowerCase().contains(queryNome);

        if (queryFaculdade.isEmpty) {
          return nomeMatch;
        }

        final rotasDoMotorista = _todasRotas.where((rota) => rota.motoristaId == motorista.id);
        final faculdadeMatch = rotasDoMotorista.any((rota) => rota.localDestinoNome.toLowerCase().contains(queryFaculdade));

        return nomeMatch && faculdadeMatch;
      }).toList();
    });
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    // Lógica de navegação para a BottomNavBar
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TelaAluno()));
        break;
      case 1:
        // Se a tela de chat for um destino fixo
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TelaListaChats()));
        break;
      case 2:
        // Já estamos aqui
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const PerfilScreen(collectionPath: 'alunos', showAppBar: true, themeColor: Colors.yellow)));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildLoginPrompt() {
      return Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: Colors.yellow,
            onPrimary: Colors.black,
          ),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Procurar Motorista'),
            backgroundColor: Colors.yellow,
            foregroundColor: Colors.black,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Faça login para procurar motoristas.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  child: const Text('Fazer Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (FirebaseAuth.instance.currentUser == null) {
      return buildLoginPrompt();
    }
    
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: Colors.yellow,
          onPrimary: Colors.black,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Procurar Motorista'),
          backgroundColor: Colors.yellow,
          foregroundColor: Colors.black,
        ),
        body: SafeArea(
          bottom: true,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome do motorista...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                child: TextField(
                  controller: _faculdadeController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por faculdade...',
                    prefixIcon: const Icon(Icons.school),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : CustomScrollView(
                        slivers: [
                          if (_motoristaVinculado != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Seu motorista',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Card.filled(
                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: _fotoMotoristaVinculado != null && _fotoMotoristaVinculado!.isNotEmpty
                                              ? NetworkImage(_fotoMotoristaVinculado!)
                                              : null,
                                          child: _fotoMotoristaVinculado == null || _fotoMotoristaVinculado!.isEmpty
                                              ? const Icon(Icons.person)
                                              : null,
                                          radius: 25,
                                        ),
                                        title: Text(
                                          _motoristaVinculado!.nome,
                                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                            'Avaliação: ${_motoristaVinculado!.avaliacao.toStringAsFixed(1)} ★'),
                                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                                                                                                                  builder: (context) => Theme(
                                                                                                                                                    data: theme,
                                                                                                                                                    child: TelaDetalheMotorista(
                                                                                                                                                      motorista: _motoristaVinculado!,
                                                                                                                                                      fotoUrl: _fotoMotoristaVinculado,
                                                                                                                                                    ),
                                                                                                                                                  ),                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Outros motoristas',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          _motoristasFiltrados.isEmpty && _motoristaVinculado == null
                              ? const SliverFillRemaining(
                                  child: Center(
                                    child: Text('Nenhum motorista encontrado.'),
                                  ),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final motorista = _motoristasFiltrados[index];
                                      final fotoUrl = _fotosMotoristas[motorista.id];

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                        child: Card.filled(
                                          margin: const EdgeInsets.symmetric(vertical: 4),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundImage: fotoUrl != null && fotoUrl.isNotEmpty
                                                  ? NetworkImage(fotoUrl)
                                                  : null,
                                              child: fotoUrl == null || fotoUrl.isEmpty
                                                  ? const Icon(Icons.person)
                                                  : null,
                                              radius: 25,
                                            ),
                                            title: Text(
                                              motorista.nome,
                                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                            ),
                                            subtitle: Text(
                                                'Avaliação: ${motorista.avaliacao.toStringAsFixed(1)} ★'),
                                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => Theme(
                                                    data: theme,
                                                    child: TelaDetalheMotorista(
                                                      motorista: motorista,
                                                      fotoUrl: fotoUrl,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: _motoristasFiltrados.length,
                                  ),
                                ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
            BottomNavigationBarItem(
                icon: Icon(Icons.search), label: 'Procurar'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person), label: 'Perfil'),
          ],
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
        ),
      ),
    );
  }
}