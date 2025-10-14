// lib/screens/tela_chat.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TelaChat extends StatefulWidget {
  final String chatId; // ID da conversa (ex: motoristaId_alunoId)
  final String nomeReceptor; // Nome da pessoa com quem se está conversando

  const TelaChat({
    super.key,
    required this.chatId,
    required this.nomeReceptor,
  });

  @override
  State<TelaChat> createState() => _TelaChatState();
}

class _TelaChatState extends State<TelaChat> {
  final _controller = TextEditingController();
  final _meuId = FirebaseAuth.instance.currentUser!.uid;

  void _enviarMensagem() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) {
      return;
    }

    _controller.clear();
    final firestore = FirebaseFirestore.instance;

    // Adiciona a nova mensagem na subcoleção 'messages' dentro do documento do chat
    await firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'texto': texto,
      'senderId': _meuId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Atualiza o documento principal do chat com a última mensagem (para a lista de conversas)
    await firestore.collection('chats').doc(widget.chatId).set({
      'lastMessage': {
        'texto': texto,
        'timestamp': FieldValue.serverTimestamp(),
      },
      'participants': widget.chatId.split('_'), // Garante que os participantes estejam lá
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nomeReceptor),
        // A cor será definida pela tela que chama o chat (motorista=vermelho, aluno=amarelo)
        backgroundColor: Theme.of(context).colorScheme.primary, 
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Comece a conversa!'));
                }

                final mensagens = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true, // Para o chat começar de baixo para cima
                  itemCount: mensagens.length,
                  itemBuilder: (context, index) {
                    final msg = mensagens[index];
                    final eMinhaMensagem = msg['senderId'] == _meuId;

                    return Align(
                      alignment: eMinhaMensagem ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: eMinhaMensagem ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          msg['texto'],
                          style: TextStyle(color: eMinhaMensagem ? Colors.white : Colors.black87),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Campo de input para digitar a mensagem
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Digite uma mensagem...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _enviarMensagem(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _enviarMensagem,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}