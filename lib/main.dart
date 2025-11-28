import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'firebase_options.dart';

import 'screens/tela_selecao.dart';
import 'screens/tela_motorista.dart';
import 'screens/tela_aluno.dart';
import 'screens/tela_login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env"); // Load .env file
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const VanGoApp());
}

class VanGoApp extends StatelessWidget {
  const VanGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const neonGreen = Color(0xFFB5FF2A);
    const deepBlack = Color(0xFF0F0F0F);
    const darkGrey = Color(0xFF1D1D1D);

    final baseTextTheme = ThemeData(brightness: Brightness.dark).textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        );

    return MaterialApp(
      title: 'VanGo',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: deepBlack,
        colorScheme: const ColorScheme.dark(
          primary: neonGreen,
          secondary: Color(0xFF7462FF),
          surface: darkGrey,
          background: deepBlack,
        ),
        textTheme: baseTextTheme,
        cardTheme: CardThemeData(
          color: darkGrey,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkGrey,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: neonGreen,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: darkGrey,
          selectedItemColor: neonGreen,
          unselectedItemColor: Colors.white70,
          showUnselectedLabels: false,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: neonGreen,
          foregroundColor: Colors.black,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      
      initialRoute: '/',
      routes: {
        '/': (context) => const TelaSelecao(),
        '/aluno': (context) => TelaAluno(),
 
        '/login': (context) => const TelaLogin(),
       '/motorista': (context) => TelaMotorista(), 
      },
    );
  }
}
