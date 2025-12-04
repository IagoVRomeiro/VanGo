import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vango/models/motorista.dart';
import 'package:vango/models/usuario.dart';
import 'package:vango/screens/tela_aluno.dart';
import 'package:vango/screens/tela_detalhe_motorista.dart';
import 'package:vango/screens/tela_notificacoes.dart';
import 'package:vango/screens/tela_perfil.dart';
import 'package:vango/screens/tela_selecao.dart';
import 'package:vango/l10n/app_localizations.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_drawer.dart';
import '../widgets/neon_bottom_nav_bar.dart';
import '../widgets/notifications_bell.dart';
import 'package:vango/services/functions_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

class TelaBuscaMotorista extends StatefulWidget {
  final bool showScaffold;
  const TelaBuscaMotorista({super.key, this.showScaffold = true});

  @override
  State<TelaBuscaMotorista> createState() => _TelaBuscaMotoristaState();
}

class _TelaBuscaMotoristaState extends State<TelaBuscaMotorista> {
  final int _selectedIndex = 2;
  String _filtroNome = '';
  String? _filtroFaculdade;
  List<String> _listaFaculdades = [];
  bool _carregando = true;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _carregandoVinculo = true;
  Motorista? _motoristaVinculado;
  Usuario? _usuarioMotoristaVinculado;
  bool _desvinculando = false;

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

  void _navigateToAlunoHome(int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => TelaAluno(initialIndex: index)),
      (route) => false,
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0:
        _navigateToAlunoHome(0);
        break;
      case 1:
        _navigateToAlunoHome(1);
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
          MaterialPageRoute(builder: (_) => TelaSelecao()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.logoutError(e.toString()))),
        );
      }
    }
  }

  Future<void> _desvincularMotorista() async {
    if (_currentUser == null || _motoristaVinculado == null) return;
    if (_desvinculando) return;
    setState(() => _desvinculando = true);
    try {
      await FunctionsService.instance.call('desvincularMotoristaAluno');
      setState(() {
        _motoristaVinculado = null;
        _usuarioMotoristaVinculado = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.unlinkSuccess)),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      final code = e.code;
      if (!mounted) return;
      if (code == 'unimplemented' || code == 'not-found') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.functionsMissing)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.unlinkError(e.message ?? e.code))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.unlinkError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _desvinculando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    if (_currentUser == null) {
      return _buildLoginPrompt(theme);
    }
    
    final body = SafeArea(
      bottom: true,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildMotoristaVinculadoSection(theme),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
                child: _buildFiltros(theme, l10n),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 16),
            sliver: _buildMotoristasSliver(theme),
          ),
        ],
      ),
    );

    if (!widget.showScaffold) {
      return body;
    }

    return Scaffold(
      appBar: NeonAppBar(
        title: 'Encontrar Motorista',
        onNotificationsPressed: _openNotifications,
        notificationAction: _currentUser != null
            ? NotificationsBell(
                role: UserRole.aluno,
                userId: _currentUser!.uid,
                onPressed: _openNotifications,
              )
            : null,
      ),
      drawer: NeonDrawer(
        onSettings: _openSettingsFromDrawer,
        onLogout: _logout,
      ),
      body: body,
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

  Widget _buildFiltros(ThemeData theme, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: l10n.searchNameHint,
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(l10n.loadingColleges),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            return DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String?>(
                initialValue: _filtroFaculdade,
                icon: const Icon(Icons.arrow_drop_down),
                isDense: true,
                isExpanded: true,
                hint: Text(l10n.filterByCollege),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.allColleges),
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
                      ),
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
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                ),
              ),
            );
          },
        ),
        if (!_carregando && _listaFaculdades.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.noColleges,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
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
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: Center(child: Text(AppLocalizations.of(context)!.noDriversFound)),
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
            AppLocalizations.of(context)!.currentDriverTitle,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        _buildMotoristaTile(
          motorista: _motoristaVinculado!,
          usuario: _usuarioMotoristaVinculado!,
          theme: theme,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton.icon(
            onPressed: _desvinculando ? null : _desvincularMotorista,
            icon: _desvinculando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_off),
            label: const Text('Desvincular motorista'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
          ),
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
            radius: 25,
            child: usuario.fotoUrl == null || usuario.fotoUrl!.isEmpty ? const Icon(Icons.person) : null,
          ),
          title: Text(usuario.nome, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          subtitle: Text(AppLocalizations.of(context)!.ratingLabel(motorista.avaliacao.toStringAsFixed(1))),
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
        appBar: NeonAppBar(
          title: AppLocalizations.of(context)!.procurarMotoristaTitle,
          showMenuButton: false,
          showNotificationsButton: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.loginToSearch, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: Text(AppLocalizations.of(context)!.loginButton),
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
      items: [
        BottomNavigationBarItem(icon: const Icon(Icons.map), label: AppLocalizations.of(context)!.navMap),
        BottomNavigationBarItem(icon: const Icon(Icons.chat), label: AppLocalizations.of(context)!.navChat),
        BottomNavigationBarItem(icon: const Icon(Icons.search), label: AppLocalizations.of(context)!.navSearch),
        BottomNavigationBarItem(icon: const Icon(Icons.person), label: AppLocalizations.of(context)!.navProfile),
      ],
    );
  }
}
