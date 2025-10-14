import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();


  final _formKey = GlobalKey<FormState>();

  // Função para lidar com a criação da conta
  Future<void> _criarConta() async {
    // 1. Validar o formulário
    if (!_formKey.currentState!.validate()) {
      return; // Se o formulário não for válido, não faz nada.
    }

    // Mostrar um diálogo de "carregando" para o usuário
    showDialog(
      context: context,
      barrierDismissible: false, // O usuário não pode fechar o diálogo
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // 2. Tentar criar o usuário no Firebase Authentication
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(), // Pega o e-mail do campo de texto
        password: _senhaController.text.trim(), // Pega a senha
      );

      // Se o código chegar aqui, o usuário foi criado com sucesso!
      // Podemos fechar o diálogo de "carregando"
      if (mounted) Navigator.of(context).pop();
      // Opcional: Navegar para a tela de login ou para a home
      // Navigator.of(context).pushReplacement(...);

    } on FirebaseAuthException catch (e) {
      // Se ocorrer um erro do Firebase, trate-o aqui
      if (mounted) Navigator.of(context).pop(); // Fecha o diálogo de "carregando"

      // Mostra uma mensagem de erro para o usuário
      String mensagemErro = 'Ocorreu um erro. Tente novamente.';
      if (e.code == 'weak-password') {
        mensagemErro = 'A senha fornecida é muito fraca.';
      } else if (e.code == 'email-already-in-use') {
        mensagemErro = 'Já existe uma conta com este e-mail.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagemErro),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      // Para qualquer outro tipo de erro
      if (mounted) Navigator.of(context).pop();
      print(e); // Imprime o erro no console para debug
    }
  }

  @override
  void dispose() {
    // Limpar os controladores quando o widget for removido da tela
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Conta'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-mail'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Por favor, insira um e-mail válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true, // Esconde a senha
                validator: (value) {
                  if (value == null || value.isEmpty || value.length < 6) {
                    return 'A senha deve ter pelo menos 6 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _criarConta, // Chama nossa função de criar conta
                child: const Text('Cadastrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}