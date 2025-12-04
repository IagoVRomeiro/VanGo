import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vango/services/email_service.dart'; // Import do novo serviço

// Imports relativos
import '../models/aluno.dart';
import '../models/motorista.dart'; // ⬅️ Precisa do enum StatusMotorista
import '../models/usuario.dart';
import 'tela_login.dart';

import 'tela_motorista.dart';
import 'tela_aluno.dart';

enum TipoUsuario { motorista, aluno }

class TelaCadastro extends StatefulWidget {
  final TipoUsuario? tipoInicial;

  const TelaCadastro({super.key, this.tipoInicial});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  late TipoUsuario _tipoUsuarioSelecionado;
  final _formKey = GlobalKey<FormState>();
  final EmailService _emailService = EmailService(); // Instância do serviço

  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _senhaVisivel = false;

  @override
  void initState() {
    super.initState();
    _tipoUsuarioSelecionado =
        widget.tipoInicial ?? TipoUsuario.motorista;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _criarConta() async {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );
      final user = cred.user;

      if (user != null) {
        await user.updateDisplayName(_nomeController.text.trim());

        final batch = FirebaseFirestore.instance.batch();
        
        // Passa o nome para ser salvo no documento 'users'
        _criarRegistroUsuario(batch, user, _nomeController.text.trim());

        if (_tipoUsuarioSelecionado == TipoUsuario.motorista) {
          _salvarMotorista(batch, user);
        } else {
          _salvarAluno(batch, user);
        }
        await batch.commit();

        // Envia o email de boas-vindas após o cadastro ser concluído
        _emailService.sendWelcomeEmail(user.email!, _nomeController.text.trim());
      }

      if (mounted) {
        Navigator.pop(context); // Fecha o loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta criada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        if (_tipoUsuarioSelecionado == TipoUsuario.motorista) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TelaMotorista()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => TelaAluno()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context); // Fecha o loading

      String errorMessage;
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Este e-mail já está em uso. Tente fazer o login.';
      } else {
        errorMessage = e.message ?? 'Ocorreu um erro de autenticação inesperado.';
      }
      _mostrarErro(errorMessage);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Fecha o loading
      _mostrarErro('Ocorreu um erro ao salvar os dados: $e');
    }
  }

  void _criarRegistroUsuario(WriteBatch batch, User user, String nome) {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final novoUsuario = Usuario(
      id: user.uid,
      nome: nome, // Salva o nome no documento principal do usuário
      email: user.email!,
      role: _tipoUsuarioSelecionado == TipoUsuario.motorista
          ? UserRole.motorista
          : UserRole.aluno,
      criadoEm: Timestamp.now(),
    );
    batch.set(userDocRef, novoUsuario.toMap());

    // Também garante que a collection motoristas/alunos tenha nome, se aplicável
    if (_tipoUsuarioSelecionado == TipoUsuario.motorista) {
      batch.set(
        FirebaseFirestore.instance.collection('motoristas').doc(user.uid),
        {'nome': nome},
        SetOptions(merge: true),
      );
    } else {
      batch.set(
        FirebaseFirestore.instance.collection('alunos').doc(user.uid),
        {'nome': nome},
        SetOptions(merge: true),
      );
    }
  }

  void _salvarMotorista(WriteBatch batch, User user) {
    final motoristaDocRef =
        FirebaseFirestore.instance.collection('motoristas').doc(user.uid);
    // Cria apenas com os campos específicos do motorista
    final novoMotorista = Motorista(
      id: user.uid,
      cpf: '',
      cnh: '',
      avaliacao: 0.0,
      status: StatusMotorista.indefinido,
    );
    batch.set(motoristaDocRef, novoMotorista.toMap());
  }

  void _salvarAluno(WriteBatch batch, User user) {
    final alunoDocRef = FirebaseFirestore.instance.collection('alunos').doc(user.uid);
    // Cria apenas com os campos específicos do aluno
    final novoAluno = Aluno(
      id: user.uid,
      motoristaId: null,
      localizacao: const GeoPoint(0, 0),
      statusPresenca: StatusPresenca.ausente,
    );
    batch.set(alunoDocRef, novoAluno.toMap());
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  SizedBox(
                    height: 100,
                    child: Image.asset('assets/iconSemFundo.png'),
                  ),
                  const SizedBox(height: 40),
                  Text('Criar Conta',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: 30),
                  SegmentedButton<TipoUsuario>(
                    segments: const [
                      ButtonSegment(
                          value: TipoUsuario.motorista,
                          label: Text('Sou Motorista'),
                          icon: Icon(Icons.drive_eta_outlined)),
                      ButtonSegment(
                          value: TipoUsuario.aluno, 
                          label: Text('Sou Aluno'),
                          icon: Icon(Icons.backpack_outlined)),
                    ],
                    selected: {_tipoUsuarioSelecionado},
                    onSelectionChanged: (s) =>
                        setState(() => _tipoUsuarioSelecionado = s.first),
                    style: SegmentedButton.styleFrom(
                      // As cores virão do tema
                    ),
                  ),
                  const SizedBox(height: 24),
                  _campoTexto(
                    controller: _nomeController,
                    dica: 'Seu nome completo',
                    icone: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _campoTexto(
                    controller: _emailController,
                    dica: 'Seu e-mail de login',
                    icone: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _campoTexto(
                    controller: _senhaController,
                    dica: 'Crie uma senha',
                    icone: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: _botaoPrincipal(
                      texto: 'CADASTRAR',
                      aoPressionar: _criarConta,
                    ),
                  ),
                  const SizedBox(height: 30),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        const TextSpan(text: 'Já tem uma conta? '),
                        TextSpan(
                          text: 'Faça login',
                          style: TextStyle(
                              color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const TelaLogin()),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String dica,
    required IconData icone,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(10);
    final baseBorderColor =
        theme.colorScheme.onSurface.withValues(alpha: 0.2); // visível em fundos claros/escuros
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? !_senhaVisivel : false,
      style: theme.textTheme.bodyLarge,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        hintText: dica,
        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 20, right: 15),
          child: Icon(icone, color: theme.colorScheme.onSurfaceVariant, size: 22),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    _senhaVisivel ? Icons.visibility_off : Icons.visibility,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: baseBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: baseBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Campo obrigatório';
        if (keyboardType == TextInputType.emailAddress && !v.contains('@')) {
          return 'E-mail inválido';
        }
        return null;
      },
    );
  }

  Widget _botaoPrincipal({
    required String texto,
    required VoidCallback aoPressionar,
  }) {
    return ElevatedButton(
      onPressed: aoPressionar,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(texto,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1)),
    );
  }
}
