import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  
  // Dados do usuário
  String nome = "Usuário Exemplo";
  String email = "usuario@email.com";
  String universidade = "PUC Minas";

  // Preferências
  bool notificacoesAtivas = true;
  bool receberEmails = false;

  // Salvar dados no Firestore
  Future<void> salvarDados() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        "nome": nome,
        "email": email,
        "universidade": universidade,
        "notificacoesAtivas": notificacoesAtivas,
        "receberEmails": receberEmails,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dados salvos com sucesso!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar: $e")),
      );
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacementNamed("/login");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao sair: $e")),
      );
    }
  }

  Future<void> escolherFoto() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Função de escolher foto ainda não implementada.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Perfil"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: salvarDados,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Foto de perfil
            GestureDetector(
              onTap: escolherFoto,
              child: const CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage("assets/images/user.png"), // imagem padrão
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.edit, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Nome
            TextField(
              decoration: const InputDecoration(labelText: "Nome"),
              controller: TextEditingController(text: nome),
              onChanged: (val) => nome = val,
            ),
            const SizedBox(height: 10),

            // Email
            TextField(
              decoration: const InputDecoration(labelText: "Email"),
              controller: TextEditingController(text: email),
              onChanged: (val) => email = val,
            ),
            const SizedBox(height: 10),

            // Universidade
            TextField(
              decoration: const InputDecoration(labelText: "Universidade"),
              controller: TextEditingController(text: universidade),
              onChanged: (val) => universidade = val,
            ),
            const Divider(height: 30),

            // Switch para notificações
            SwitchListTile(
              title: const Text("Ativar notificações"),
              value: notificacoesAtivas,
              onChanged: (bool novoValor) {
                setState(() {
                  notificacoesAtivas = novoValor;
                });
              },
            ),

            // Checkbox para receber emails
            CheckboxListTile(
              title: const Text("Receber emails"),
              value: receberEmails,
              onChanged: (bool? novoValor) {
                setState(() {
                  receberEmails = novoValor ?? false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
