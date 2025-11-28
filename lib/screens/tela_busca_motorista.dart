// lib/screens/tela_busca_motorista.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vango/models/motorista.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/screens/tela_aluno.dart';
import 'package:vango/screens/tela_detalhe_motorista.dart';
import 'package:vango/screens/tela_lista_chats.dart';
import 'package:vango/screens/tela_notificacoes.dart';
import 'package:vango/screens/tela_perfil.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_drawer.dart';
import '../widgets/neon_bottom_nav_bar.dart';

class TelaBuscaMotorista extends StatefulWidget {
  const TelaBuscaMotorista({super.key});

  @override
  State<TelaBuscaMotorista> createState() => _TelaBuscaMotoristaState();
}

class _TelaBuscaMotoristaState extends State<TelaBuscaMotorista> {
  int _selectedIndex = 2;
  String _filtroNome = '';
  String? _filtroFaculdade;
  List<String> _listaFaculdades = [];
  bool _carregando = true;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _carregandoVinculo = true;
  Motorista? _motoristaVinculado;
  Usuario? _usuarioMotoristaVinculado;

  List<Map<String, dynamic>> _motoristasCompletos = [];
  List<Map<String, dynamic>> _motoristasFiltrados = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _carregarMotoristaVinculado();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    await _carregarFaculdades();
    await _carregarMotoristas();
    if (mounted) {
      setState(() => _carregando = false);
    }
  }

  Future<void> _carregarMotoristaVinculado() async {
    final alunoId = _currentUser?.uid;
    if (alunoId == null) {
      if (mounted) {
        setState(() {
          _carregandoVinculo = false;
          _motoristaVinculado = null;
          _usuarioMotoristaVinculado = null;
        });
      }
      return;
    }

    try {
      final alunoDoc = await FirebaseFirestore.instance.collection('alunos').doc(alunoId).get();
      final motoristaId = alunoDoc.data()?['motoristaId'] as String?;

      if (motoristaId == null || motoristaId.isEmpty) {
        if (mounted) {
          setState(() {
            _motoristaVinculado = null;
            _usuarioMotoristaVinculado = null;
            _carregandoVinculo = false;
          });
        }
        return;
      }

      final motoristaDoc = await FirebaseFirestore.instance.collection('motoristas').doc(motoristaId).get();
      final usuarioDoc = await FirebaseFirestore.instance.collection('users').doc(motoristaId).get();

      if (!motoristaDoc.exists || !usuarioDoc.exists) {
        if (mounted) {
          setState(() {
            _motoristaVinculado = null;
            _usuarioMotoristaVinculado = null;
            _carregandoVinculo = false;
          });
        }
        return;
      }

      final motorista = Motorista.fromMap(motoristaDoc.id, motoristaDoc.data()!);
      final usuario = Usuario.fromSnapshot(usuarioDoc);

      if (mounted) {
        setState(() {
          _motoristaVinculado = motorista;
          _usuarioMotoristaVinculado = usuario;
          _carregandoVinculo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _motoristaVinculado = null;
          _usuarioMotoristaVinculado = null;
          _carregandoVinculo = false;
        });
      }
    }
  }

  Future<void> _carregarFaculdades() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('rotas').get();
      final faculdades = snapshot.docs
          .map((doc) => doc.data()['localDestinoNome'])
          .whereType<String>()
          .where((nome) => nome.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (mounted) {
        setState(() {
          _listaFaculdades = faculdades;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _carregarMotoristas() async {
    try {
      final motoristasSnapshot = await FirebaseFirestore.instance.collection('motoristas').get();
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final rotasSnapshot = await FirebaseFirestore.instance.collection('rotas').get();

      final usersMap = {for (var doc in usersSnapshot.docs) doc.id: doc};
      final rotasPorMotorista = <String, List<String>>{};
      for (var rota in rotasSnapshot.docs) {
        final motoristaId = rota.data()['motoristaId'] as String;
        final faculdade = rota.data()['localDestinoNome'] as String;
        if (rotasPorMotorista.containsKey(motoristaId)) {
          rotasPorMotorista[motoristaId]!.add(faculdade);
        } else {
          rotasPorMotorista[motoristaId] = [faculdade];
        }
      }

      final motoristas = motoristasSnapshot.docs.map((motoristaDoc) {
        final userDoc = usersMap[motoristaDoc.id];
        if (userDoc != null) {
          final motorista = Motorista.fromMap(motoristaDoc.id, motoristaDoc.data());
          final usuario = Usuario.fromSnapshot(userDoc as DocumentSnapshot<Map<String, dynamic>>);
          final faculdadesDoMotorista = rotasPorMotorista[motorista.id] ?? [];

          return {
            'motorista': motorista,
            'usuario': usuario,
            'faculdades': faculdadesDoMotorista,
          };
        }
        return null;
      }).whereType<Map<String, dynamic>>().toList();
      
      if (mounted) {
        setState(() {
          _motoristasCompletos = motoristas;
          _motoristasFiltrados = motoristas;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  void _filtrarMotoristas() {
    List<Map<String, dynamic>> filtrados = List.from(_motoristasCompletos);

    if (_filtroNome.isNotEmpty) {
      final termo = _filtroNome.toLowerCase();
      filtrados = filtrados.where((data) {
        final usuario = data['usuario'] as Usuario;
        return usuario.nome.toLowerCase().contains(termo);
      }).toList();
    }

    if (_filtroFaculdade != null) {
      final filtroFac = _filtroFaculdade!;
      filtrados = filtrados.where((data) {
        final faculdades = data['faculdades'] as List<String>;
        return faculdades.contains(filtroFac);
      }).toList();
    }

    setState(() {
      _motoristasFiltrados = filtrados;
    });
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TelaAluno()));
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TelaListaChats(showAppBar: true)),
        );
        break;
      case 2:
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const PerfilScreen(collectionPath: 'alunos', showAppBar: true)));
        break;
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => TelaAluno()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao sair: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_currentUser == null) {
      return _buildLoginPrompt(theme);
    }
    
    return Scaffold(
        appBar: NeonAppBar(
          title: 'Encontrar Motorista',
          onNotificationsPressed: _openNotifications,
        ),
        drawer: NeonDrawer(
          items: _buildDrawerItems(context),
          onSettings: _openSettingsFromDrawer,
          onLogout: _logout,
        ),
        body: SafeArea(
          bottom: true,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildMotoristaVinculadoSection(theme),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _buildFiltros(theme),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 16),
                sliver: _buildMotoristasSliver(theme),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TelaNotificacoes()),
    );
  }

  Future<void> _openSettingsFromDrawer() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const PerfilScreen(collectionPath: 'alunos', showAppBar: true),
      ),
    );
  }

  List<NeonDrawerItem> _buildDrawerItems(BuildContext context) {
    return [
      NeonDrawerItem(
        icon: Icons.map,
        label: 'Mapa',
        onTap: () async {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TelaAluno()));
        },
      ),
      NeonDrawerItem(
        icon: Icons.chat,
        label: 'Conversas',
        onTap: () async {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TelaListaChats(showAppBar: true)),
          );
        },
      ),
      NeonDrawerItem(
        icon: Icons.search,
        label: 'Procurar Motorista',
        onTap: () async {},
      ),
      NeonDrawerItem(
        icon: Icons.person,
        label: 'Meu Perfil',
        onTap: () async {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const PerfilScreen(collectionPath: 'alunos', showAppBar: true)));
        },
      ),
    ];
  }

  Widget _buildFiltros(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Buscar por nome...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
          ),
          onChanged: (value) {
            setState(() {
              _filtroNome = value;
            });
            _filtrarMotoristas();
          },
        ),
        const SizedBox(height: 10),
        if (_carregando)
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text("Carregando faculdades..."),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            return DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String?>(
                value: _filtroFaculdade,
                icon: const Icon(Icons.arrow_drop_down),
                isDense: true,
                isExpanded: true,
                hint: const Text('Filtrar por faculdade'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas as faculdades'),
                  ),
                  ..._listaFaculdades
                      .map(
                        (faculdade) => DropdownMenuItem<String?>(
                          value: faculdade,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: constraints.maxWidth - 32),
                            child: Text(
                              faculdade,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ],
                onChanged: _carregando
                    ? null
                    : (value) {
                        setState(() {
                          _filtroFaculdade = value;
                        });
                        _filtrarMotoristas();
                  },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                ),
              ),
            );
          },
        ),
        if (!_carregando && _listaFaculdades.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Nenhuma faculdade cadastrada. Cadastre rotas para liberar filtros.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMotoristasSliver(ThemeData theme) {
    if (_carregando) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_motoristasFiltrados.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48.0),
          child: Center(child: Text('Nenhum motorista encontrado.')),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final data = _motoristasFiltrados[index];
          final motorista = data['motorista'] as Motorista;
          final usuario = data['usuario'] as Usuario;

          return _buildMotoristaTile(
            motorista: motorista,
            usuario: usuario,
            theme: theme,
          );
        },
        childCount: _motoristasFiltrados.length,
      ),
    );
  }

  Widget _buildMotoristaVinculadoSection(ThemeData theme) {
    if (_carregandoVinculo) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: LinearProgressIndicator(minHeight: 3),
      );
    }

    if (_motoristaVinculado == null || _usuarioMotoristaVinculado == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'Seu motorista atual',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        _buildMotoristaTile(
          motorista: _motoristaVinculado!,
          usuario: _usuarioMotoristaVinculado!,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildMotoristaTile({
    required Motorista motorista,
    required Usuario usuario,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Card.filled(
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage: usuario.fotoUrl != null && usuario.fotoUrl!.isNotEmpty ? NetworkImage(usuario.fotoUrl!) : null,
            child: usuario.fotoUrl == null || usuario.fotoUrl!.isEmpty ? const Icon(Icons.person) : null,
            radius: 25,
          ),
          title: Text(usuario.nome, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          subtitle: Text('Avaliação: ${motorista.avaliacao.toStringAsFixed(1)} ★'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Theme(
                  data: theme,
                  child: TelaDetalheMotorista(
                    motorista: motorista,
                    nome: usuario.nome,
                    fotoUrl: usuario.fotoUrl,
                    telefone: usuario.telefone,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(ThemeData theme) {
    return Scaffold(
        appBar: const NeonAppBar(
          title: 'Procurar Motorista',
          showMenuButton: false,
          showNotificationsButton: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Faça login para procurar motoristas.', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('Fazer Login'),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildBottomNavBar() {
    return NeonBottomNavBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Procurar'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
    );
  }
}
