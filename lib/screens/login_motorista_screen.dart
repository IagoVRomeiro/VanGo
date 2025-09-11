
import 'package:flutter/material.dart';

class LoginMotoristaScreen extends StatelessWidget {
  const LoginMotoristaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acesso Motorista'),
        backgroundColor: const Color(0xFF333333),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Tela de Login do Motorista'),
      ),
    );
  }
}