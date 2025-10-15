
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Imports relativos para seus arquivos
import 'screens/tela_selecao.dart';
import 'screens/tela_motorista.dart';
import 'screens/tela_aluno.dart';
import 'screens/tela_login.dart';

// O resto do seu código do main.dart...
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const VanGoApp());
}

class VanGoApp extends StatelessWidget {
  const VanGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VanGo',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // ✅ CORREÇÃO: Rotas usando os nomes das classes diretamente.
      initialRoute: '/',
      routes: {
        '/': (context) => const TelaSelecao(),
        '/aluno': (context) => const TelaAluno(), // Supondo que TelaAluno exista
        '/login': (context) => const TelaLogin(),
        // A rota motorista é mais complexa e é melhor tratada com onGenerateRoute
        // mas para o seu caso atual, uma rota simples funciona.
        '/motorista': (context) => const TelaMotorista(),
      },
    );
  }
}