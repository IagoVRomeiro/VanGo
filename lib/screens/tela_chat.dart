// lib/screens/tela_chat.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vango/models/mensagem.dart'; 

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
  
  final String? _meuId = FirebaseAuth.instance.currentUser?.uid;

  
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
      return;
    }

    _controller.clear();
    final firestore = FirebaseFirestore.instance;

    final chatDocRef = firestore.collection('chats').doc(widget.chatId);
    final messagesColRef = chatDocRef.collection('messages');

    
    try {
      
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
                    enabled: _meuId != null,
                  ),
                ),
                IconButton(
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