import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// Imports relativos
import '../models/aluno.dart';
import '../models/motorista.dart';
import '../models/usuario.dart';
import 'tela_login.dart';

import 'tela_motorista.dart'; // ⬅️ IMPORT CORRIGIDO: Tela do Motorista
import 'tela_aluno.dart';    // ⬅️ IMPORT CORRIGIDO: Tela do Aluno


enum TipoUsuario { motorista, aluno }

class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  TipoUsuario _tipoUsuarioSelecionado = TipoUsuario.motorista;
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _senhaVisivel = false;

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
      final batch = FirebaseFirestore.instance.batch();
      _criarRegistroUsuario(batch, user);

      if (_tipoUsuarioSelecionado == TipoUsuario.motorista) {
        _salvarMotorista(batch, user);
      } else {
        _salvarAluno(batch, user);
      }

      await batch.commit();
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta criada com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );

      // 💥 LÓGICA DE REDIRECIONAMENTO CONDICIONAL E SEM 'CONST'
      if (_tipoUsuarioSelecionado == TipoUsuario.motorista) {
        Navigator.pushReplacement(
          context,
          // Agora o construtor é chamado corretamente, sem 'const'
          MaterialPageRoute(builder: (_) =>  TelaMotorista()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          // Agora o construtor é chamado corretamente, sem 'const'
          MaterialPageRoute(builder: (_) =>  TelaAluno()),
        );
      }
    }
  } on FirebaseAuthException catch (e) {
    if (mounted) Navigator.pop(context);
    
    String errorMessage;
    if (e.code == 'email-already-in-use') {
      errorMessage =
          'Este e-mail já está em uso. Tente fazer o login.';
    } else {
      errorMessage = e.message ?? 'Ocorreu um erro de autenticação inesperado.';
    }

    _mostrarErro(errorMessage);

  } catch (e) {
    if (mounted) Navigator.pop(context);
    _mostrarErro('Ocorreu um erro ao salvar os dados: $e');
  }
}

  void _criarRegistroUsuario(WriteBatch batch, User user) {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final novoUsuario = Usuario(
      id: user.uid,
      email: user.email!,
      role: _tipoUsuarioSelecionado == TipoUsuario.motorista
          ? UserRole.motorista
          : UserRole.aluno,
      criadoEm: Timestamp.now(),
    );
    batch.set(userDocRef, novoUsuario.toMap());
  }

  void _salvarMotorista(WriteBatch batch, User user) {
    final motoristaDocRef = FirebaseFirestore.instance.collection('motoristas').doc(user.uid);
    final novoMotorista = Motorista(
      id: user.uid,
      nome: _nomeController.text.trim(),
      email: user.email!,
      cpf: '',
      cnh: '',
      telefone: '',
      endereco: '',
      avaliacao: 0.0,
      status: StatusMotorista.indisponivel,
    );
    batch.set(motoristaDocRef, novoMotorista.toMap());
  }

  void _salvarAluno(WriteBatch batch, User user) {
    final alunoDocRef = FirebaseFirestore.instance.collection('alunos').doc(user.uid);
    final novoAluno = Aluno(
      id: user.uid,
      nome: _nomeController.text.trim(),
      motoristaId: null,
      endereco: '',
      localizacao: GeoPoint(0, 0),
      faculdade: '',
      horarioEntrada: '',
      horarioSaida: '',
      statusPresenca: StatusPresenca.desconhecido,
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
    const Color corVermelhaPrincipal = Color(0xFFE53935);
    const Color fundoEscuro = Color(0xFF2d2d2d);
    const Color amareloBotao = Color(0xFFFFB300);
    const Color branco = Colors.white;

    return Scaffold(
      backgroundColor: corVermelhaPrincipal,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // 🎯 CORREÇÃO: Restaurando o uso de Image.asset com o caminho confirmado
                  SizedBox(
                    height: 100,
                    child: Image.asset('assets/images/vgo_logo.png'), 
                  ),
                  const SizedBox(height: 40),
                  const Text('Criar Conta', style: TextStyle(color: branco, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 30),
                  Container(
                    decoration: BoxDecoration(color: fundoEscuro, borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.all(4),
                    child: SegmentedButton<TipoUsuario>(
                      segments: const [
                        ButtonSegment(value: TipoUsuario.motorista, label: Text('Sou Motorista')),
                        ButtonSegment(value: TipoUsuario.aluno, label: Text('Sou Aluno')),
                      ],
                      selected: {_tipoUsuarioSelecionado},
                      onSelectionChanged: (s) => setState(() => _tipoUsuarioSelecionado = s.first),
                      style: SegmentedButton.styleFrom(
                        backgroundColor: fundoEscuro,
                        foregroundColor: branco,
                        selectedBackgroundColor: amareloBotao,
                        selectedForegroundColor: fundoEscuro,
                      ),
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
                      corDeFundo: amareloBotao,
                      corDoTexto: fundoEscuro,
                      aoPressionar: _criarConta,
                    ),
                  ),
                  const SizedBox(height: 30),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(color: branco, fontSize: 15),
                      children: [
                        const TextSpan(text: 'Já tem uma conta? '),
                        TextSpan(
                          text: 'Faça login',
                          style: const TextStyle(color: amareloBotao, fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const TelaLogin()),
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
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? !_senhaVisivel : false,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF2d2d2d),
        hintText: dica,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 20, right: 15),
          child: Icon(icone, color: Colors.white, size: 22),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility, color: Colors.white.withOpacity(0.7)),
                onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Campo obrigatório';
        if (keyboardType == TextInputType.emailAddress && !v.contains('@')) return 'E-mail inválido';
        return null;
      },
    );
  }

  Widget _botaoPrincipal({
    required String texto,
    required Color corDeFundo,
    required Color corDoTexto,
    required VoidCallback aoPressionar,
  }) {
    return ElevatedButton(
      onPressed: aoPressionar,
      style: ElevatedButton.styleFrom(
        backgroundColor: corDeFundo,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 5,
      ),
      child: Text(texto, style: TextStyle(color: corDoTexto, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
    );
  }
}
