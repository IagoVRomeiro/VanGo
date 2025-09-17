import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Necessário para o debugPrint

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  // Chave para validar o nosso formulário
  final _formKey = GlobalKey<FormState>();

  // Controllers para gerir o texto dos campos
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();

  // Variáveis de estado da UI
  bool _obscureText = true;
  bool _estaCarregando = false;

  @override
  void dispose() {
    // Limpar os controllers para evitar vazamento de memória
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  /// Função para lidar com o processo de cadastro do utilizador no Firebase
  Future<void> _cadastrarUtilizador() async {
    // Valida os campos do formulário
    if (_formKey.currentState?.validate() ?? false) {
      // Ativa o indicador de carregamento
      setState(() {
        _estaCarregando = true;
      });

      try {
        // Tenta criar o usuário no Firebase Authentication
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _senhaController.text.trim(),
        );

        // Se o cadastro for bem-sucedido, exibe uma mensagem
        debugPrint('Usuário criado com sucesso: ${userCredential.user?.uid}');
        
        // Opcional: Salvar informações adicionais (como o nome) no Firestore aqui.

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cadastro realizado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          // TODO: Navegar para a tela principal ou de login após o sucesso
          // Navigator.of(context).pop();
        }
      } on FirebaseAuthException catch (e) {
        // Trata erros específicos do Firebase
        debugPrint('Erro de autenticação do Firebase: ${e.code}');
        String mensagemErro = 'Ocorreu um erro desconhecido.';
        if (e.code == 'email-already-in-use') {
          mensagemErro = 'Este endereço de email já está em uso.';
        } else if (e.code == 'weak-password') {
          mensagemErro = 'A senha fornecida é muito fraca.';
        } else if (e.code == 'invalid-email') {
          mensagemErro = 'O email fornecido não é válido.';
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensagemErro),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        // Trata quaisquer outros erros
        debugPrint('Erro inesperado: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ocorreu um erro inesperado. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        // Garante que o indicador de carregamento seja desativado
        if (mounted) {
          setState(() {
            _estaCarregando = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Nova Conta'),
        backgroundColor: const Color(0xFF333333),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // --- Campo Nome ---
                TextFormField(
                  controller: _nomeController,
                  decoration: InputDecoration(
                    labelText: 'Nome Completo',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, insira o seu nome.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // --- Campo Email ---
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, insira um email.';
                    }
                    // Validação de email com Expressão Regular (RegEx)
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(value)) {
                      return 'Por favor, insira um email válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // --- Campo Senha ---
                TextFormField(
                  controller: _senhaController,
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'A senha deve ter pelo menos 6 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // --- Campo Confirmar Senha ---
                TextFormField(
                  controller: _confirmarSenhaController,
                  obscureText: true, // Geralmente não precisa de botão de visibilidade
                  decoration: InputDecoration(
                    labelText: 'Confirmar Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value != _senhaController.text) {
                      return 'As senhas não correspondem.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // --- Botão de Cadastrar ---
                ElevatedButton(
                  // Desabilita o botão enquanto está carregando
                  onPressed: _estaCarregando ? null : _cadastrarUtilizador,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF333333),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _estaCarregando
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'CADASTRAR',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}