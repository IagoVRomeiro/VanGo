
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/tela_selecao.dart';
import 'screens/tela_motorista.dart';
import 'screens/tela_aluno.dart';
import 'screens/tela_login.dart';

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
      
      initialRoute: '/',
      routes: {
        '/': (context) => const TelaSelecao(),
        '/aluno': (context) => const TelaAluno(), 
        '/login': (context) => const TelaLogin(),
        '/motorista': (context) => const TelaMotorista(),
      },
    );
  }
}