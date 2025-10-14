// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// 1. Importe todas as suas telas
import 'package:vango/screens/tela_selecao.dart';
import 'package:vango/screens/tela_motorista.dart';
import 'package:vango/screens/tela_aluno.dart';
import 'package:vango/screens/tela_login.dart'; // Importe a tela de login também

void main() async {
  // Garante a inicialização do Flutter e do Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MeuAplicativo());
}

class MeuAplicativo extends StatelessWidget {
  const MeuAplicativo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VanGo',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFE53935),
      ),
      debugShowCheckedModeBanner: false,
      
      // 2. Configure as rotas nomeadas
      initialRoute: '/', // Define a rota inicial
      routes: {
        // A rota '/' (raiz) corresponde à TelaSelecao
        '/': (context) => const TelaSelecao(), 
        // A rota '/motorista' corresponde à TelaMotorista
        '/motorista': (context) => const TelaMotorista(),
        // A rota '/aluno' corresponde à TelaAluno
        '/aluno': (context) => const AlunoHomeScreen(), 
        // É uma boa prática adicionar outras telas principais aqui também
        '/login': (context) => const TelaLogin(),
      },
    );
  }
}