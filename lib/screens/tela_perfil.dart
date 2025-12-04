import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vango/services/storage_service.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'tela_login.dart';
import 'tela_notificacoes.dart';
import '../widgets/neon_app_bar.dart';
import '../widgets/neon_bottom_nav_bar.dart';
import '../widgets/neon_drawer.dart';
import '../widgets/notifications_bell.dart';
import '../models/usuario.dart';
import 'tela_selecao.dart';

class PerfilNavResult {
  final int targetIndex;
  final bool isDriver;

  const PerfilNavResult({
    required this.targetIndex,
    required this.isDriver,
  });
}

class PerfilScreen extends StatefulWidget {
  final String collectionPath;
  final bool showAppBar;
  final Color? themeColor;

  const PerfilScreen({
    super.key,
    required this.collectionPath,
    this.showAppBar = true,
    this.themeColor,
  });

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final StorageService _storageService = StorageService();
  late final String _apiKey;
  bool _isLoading = true;
  String? _errorMessage;

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _enderecoController = TextEditingController();
  final TextEditingController _cnhController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();

  final _telefoneMaskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  final _cpfMaskFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  String? _fotoUrl;
  GeoPoint? _localizacao;
  String _initialAddress = "";
  bool _isSaving = false;
  final FocusNode _enderecoFocusNode = FocusNode();

  bool get _isDriver => widget.collectionPath == 'motoristas';

  @override
  void initState() {
    super.initState();
    _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    _verificarLoginECarregar();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _enderecoController.dispose();
    _enderecoFocusNode.dispose();
    _cnhController.dispose();
    _telefoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  void _verificarLoginECarregar() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TelaLogin()),
          (route) => false,
        );
      });
      return;
    }
    _carregarDadosDoUsuario();
  }

  Future<void> _carregarDadosDoUsuario() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Usuário não está logado.");
      }

      final profileDoc = await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(user.uid)
          .get();

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (profileDoc.exists && userDoc.exists && mounted) {
        final profileData = profileDoc.data()!;
        final userData = userDoc.data()!;

        setState(() {
          _emailController.text = user.email ?? userData['email'] ?? '';
          _fotoUrl = userData['fotoUrl'];

          _nomeController.text = userData['nome'] ?? '';
          _localizacao = profileData['localizacao'] as GeoPoint?;

          _telefoneController.text = userData['telefone'] ?? '';
          
          _initialAddress = userData['endereco'] ?? '';
          _enderecoController.text = _initialAddress;

          if (_isDriver) {
            _cnhController.text = profileData['cnh'] ?? '';
            _cpfController.text = profileData['cpf'] ?? '';
          }
        });
      } else if (mounted) {
        throw Exception("Documentos de perfil ou usuário não encontrados.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Erro ao carregar dados: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _salvarDados() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    String enderecoTexto = _enderecoController.text.trim();

    Map<String, dynamic> dadosParaSalvar = {
      "localizacao": _localizacao,
    };

    if (_isDriver) {
      dadosParaSalvar.addAll({
        "cnh": _cnhController.text.trim(),
        "cpf": _cpfMaskFormatter.getUnmaskedText(),
      });
    }

    try {
      await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .doc(uid)
          .set(dadosParaSalvar, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'nome': _nomeController.text.trim(),
        'endereco': enderecoTexto,
        'telefone': _telefoneMaskFormatter.getUnmaskedText(),
      });

      if (mounted) {
        setState(() {
           _initialAddress = enderecoTexto;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Dados salvos com sucesso!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao salvar dados: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _requestGalleryPermission() async {
    if (kIsWeb) return true;

    PermissionStatus status;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      status = await Permission.photos.request();
    } else {
      status = await Permission.storage.request();
      if (!status.isGranted && !status.isPermanentlyDenied) {
        status = await Permission.photos.request();
      }
    }

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permissão para acessar a galeria foi negada permanentemente. Ajuste nas configurações do aparelho.',
            ),
          ),
        );
      }
      await openAppSettings();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão para acessar a galeria negada.')),
      );
    }

    return false;
  }

  Future<void> _escolherEUploadFoto() async {
    final hasPermission = await _requestGalleryPermission();
    if (!hasPermission) return;

    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("Usuário não está logado.");

      final downloadUrl =
          await _storageService.uploadProfileImage(uid, pickedFile);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fotoUrl': downloadUrl});

      if (mounted) {
        setState(() {
          _fotoUrl = downloadUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto de perfil atualizada!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao atualizar a foto: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TelaSelecao()),
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

  void _goToNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TelaNotificacoes()),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEnderecoField(BuildContext context) {
    if (_apiKey.isEmpty || _apiKey == 'YOUR_API_KEY') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _enderecoController,
            focusNode: _enderecoFocusNode,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: "Endereço",
              hintText: 'Configure GOOGLE_MAPS_API_KEY no arquivo assets/.env',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Não foi possível carregar o autocomplete sem a chave da API do Google Maps.',
            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
          ),
        ],
      );
    }

    return GooglePlaceAutoCompleteTextField(
      textEditingController: _enderecoController,
      focusNode: _enderecoFocusNode,
      googleAPIKey: _apiKey,
      inputDecoration: const InputDecoration(labelText: "Endereço"),
      debounceTime: 400,
      language: 'pt-BR',
      countries: const ["br"],
      isLatLngRequired: true,
      textStyle: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
      itemClick: (Prediction prediction) {
        _enderecoController.text = prediction.description ?? '';
        _enderecoController.selection = TextSelection.fromPosition(
          TextPosition(offset: prediction.description?.length ?? 0),
        );
      },
      getPlaceDetailWithLatLng: (Prediction prediction) {
        if (prediction.lat != null && prediction.lng != null) {
          setState(() {
            _localizacao = GeoPoint(
              double.parse(prediction.lat!),
              double.parse(prediction.lng!),
            );
          });
        }
      },
      itemBuilder: (context, index, Prediction prediction) {
        return ListTile(
          dense: true,
          title: Text(prediction.description ?? ''),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final Widget bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
            ? Center(child: Text(_errorMessage!))
            : SafeArea(
                bottom: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      Center(
                        child: GestureDetector(
                          onTap: _escolherEUploadFoto,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey.shade300,
                            child: _fotoUrl == null || _fotoUrl!.isEmpty
                                ? const Icon(Icons.person, size: 50)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: Image.network(
                                      _fotoUrl!,
                                      key: ValueKey(_fotoUrl!),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, progress) {
                                        if (progress == null) return child;
                                        return const Center(
                                            child: CircularProgressIndicator());
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Icon(Icons.error, size: 50);
                                      },
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle("Dados Pessoais"),
                      TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(labelText: "Nome"),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: "Email"),
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      _buildEnderecoField(context),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _telefoneController,
                        decoration: const InputDecoration(labelText: "Telefone"),
                        inputFormatters: [_telefoneMaskFormatter],
                      ),
                      const SizedBox(height: 16),
                      if (_isDriver) ...[
                        _buildSectionTitle("Dados do Motorista"),
                        TextFormField(
                          controller: _cpfController,
                          decoration: const InputDecoration(labelText: "CPF"),
                          inputFormatters: [_cpfMaskFormatter],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _cnhController,
                          decoration: const InputDecoration(labelText: "CNH"),
                        ),
                      ],
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _salvarDados,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: const Text('SALVAR ALTERAÇÕES'),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _showDeleteConfirmationDialog,
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Deletar Conta'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              );

    if (!widget.showAppBar) {
      return bodyContent;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: NeonAppBar(
        title: "Meu Perfil",
        onNotificationsPressed: _goToNotifications,
        notificationAction: userId == null
            ? null
            : NotificationsBell(
                role: _isDriver ? UserRole.motorista : UserRole.aluno,
                userId: userId,
                onPressed: _goToNotifications,
              ),
      ),
      body: bodyContent,
      drawer: NeonDrawer(
        onSettings: _openSettingsFromDrawer,
        onLogout: _logout,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    if (_isDriver) {
      return NeonBottomNavBar(
        currentIndex: 4,
        onTap: (index) {
          if (index == 4) return;
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop(
              PerfilNavResult(targetIndex: index, isDriver: true),
            );
          } else {
            Navigator.pushReplacementNamed(context, '/motorista');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(
              icon: Icon(Icons.edit_road_outlined), label: 'Viagem'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_outlined), label: 'Alunos'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      );
    }

    return NeonBottomNavBar(
      currentIndex: 3,
      onTap: (index) {
        if (index == 3) return;
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(
            PerfilNavResult(targetIndex: index, isDriver: false),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/aluno');
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Procurar'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
    );
  }

  Future<void> _openSettingsFromDrawer() async {
    // Já estamos na tela de configurações/perfil.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Você já está na tela de configurações.')),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Deletar Conta"),
          content: const Text(
              "Tem certeza que deseja deletar sua conta? Esta ação é irreversível e todos os seus dados serão perdidos."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child:
                  const Text("Deletar", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nenhum usuário logado para deletar.")),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await user.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Conta deletada com sucesso.")),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TelaLogin()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      if (e.code == 'requires-recent-login') {
        message = "Por segurança, faça login novamente para deletar sua conta.";
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(message), duration: const Duration(seconds: 5)),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TelaLogin()),
          (route) => false,
        );
        return;
      } else {
        message = "Erro ao deletar conta: ${e.message}";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ocorreu um erro inesperado: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
