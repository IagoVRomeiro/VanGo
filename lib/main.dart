import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vango/screens/tela_selecao.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
      home: const TelaSelecao(), 
    );
  }
}