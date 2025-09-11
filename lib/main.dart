

import 'package:interface_app2/screens/selection_screen.dart';

import 'package:firebase_core/firebase_core.dart'; 

import 'package:flutter/material.dart';


// Função main com a inicialização do Firebase.
void main() async {
  // Garante que os widgets do Flutter estejam inicializados.
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa o Firebase.
  await Firebase.initializeApp();
  // Inicia o aplicativo.
  runApp(const MyApp());
}

// Widget principal que configura o MaterialApp.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VanGo App',
      theme: ThemeData(
        primaryColor: const Color(0xFFD32F2F), 
        fontFamily: 'Roboto',
      ),
      // A tela inicial agora é importada de seu próprio arquivo.
      home: const SelectionScreen(), 
      debugShowCheckedModeBanner: false,
    );
  }
}