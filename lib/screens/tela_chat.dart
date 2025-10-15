// lib/screens/tela_chat.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vango/models/mensagem.dart'; // ✅ NOVO: Importar o modelo Mensagem

class TelaChat extends StatefulWidget {
  final String chatId;
  final String nomeReceptor;

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
  // ✅ ALTERADO: Tratamento de null safety para o ID do usuário.
  final String? _meuId = FirebaseAuth.instance.currentUser?.uid;

  // ✅ NOVO: Stream agora retorna uma lista de objetos Mensagem.
  late final Stream<List<Mensagem>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Mensagem.fromSnapshot(doc))
            .toList());
  }

  Future<void> _enviarMensagem() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty || _meuId == null) {
      // Impede o envio se não houver texto ou se o usuário não estiver logado
      return;
    }

    _controller.clear();
    final firestore = FirebaseFirestore.instance;

    final chatDocRef = firestore.collection('chats').doc(widget.chatId);
    final messagesColRef = chatDocRef.collection('messages');

    // ✅ NOVO: Tratamento de erro para operações de escrita.
    try {
      // Adiciona a nova mensagem
      await messagesColRef.add({
        'texto': texto,
        'senderId': _meuId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Atualiza o documento principal do chat
      await chatDocRef.set({
        'lastMessage': {
          'texto': texto,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'participants': widget.chatId.split('_'),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar mensagem: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nomeReceptor),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            // ✅ ALTERADO: StreamBuilder agora espera uma List<Mensagem>.
            child: StreamBuilder<List<Mensagem>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Comece a conversa!'));
                }

                final mensagens = snapshot.data!;

                return ListView.builder(
                  reverse: true,
                  itemCount: mensagens.length,
                  itemBuilder: (context, index) {
                    final mensagem = mensagens[index];
                    final eMinhaMensagem = mensagem.senderId == _meuId;

                    return Align(
                      alignment: eMinhaMensagem ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: eMinhaMensagem ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // ✅ ALTERADO: Usa as propriedades do objeto Mensagem.
                        child: Text(
                          mensagem.texto,
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
                    // Desabilita o campo se o usuário não estiver logado
                    enabled: _meuId != null,
                  ),
                ),
                IconButton(
                  // Desabilita o botão se o usuário não estiver logado
                  onPressed: _meuId != null ? _enviarMensagem : null,
                  icon: const Icon(Icons.send),
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