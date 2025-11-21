// lib/screens/tela_chat.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart'; // Import for DateFormat

import 'package:vango/models/mensagem.dart'; 



class TelaChat extends StatefulWidget {



  final String chatId;



  final String nomeReceptor;



  final String receptorId; // ⬅️ ADICIONADO







  const TelaChat({



    super.key,



    required this.chatId,



    required this.nomeReceptor,



    required this.receptorId, // ⬅️ ADICIONADO



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







    final meuId = _meuId!;



    _controller.clear();



    final firestore = FirebaseFirestore.instance;







    final chatDocRef = firestore.collection('chats').doc(widget.chatId);



    final messagesColRef = chatDocRef.collection('messages');







    



    try {



      // Garante que o documento de chat exista com os participantes corretos



      await chatDocRef.set({



        'participants': [meuId, widget.receptorId]..sort(), // Garante a ordem



        'lastMessage': {



          'texto': texto,



          'timestamp': FieldValue.serverTimestamp(),



        },



      }, SetOptions(merge: true)); // Usa merge para não sobrescrever se já existir







      // Adiciona a nova mensagem



      await messagesColRef.add({



        'texto': texto,



        'senderId': meuId,



        'timestamp': FieldValue.serverTimestamp(),



      });







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



      final theme = Theme.of(context);



      return Scaffold(



        appBar: AppBar(



          title: Text(widget.nomeReceptor),



          // A cor da AppBar virá do tema geral



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



                    padding: const EdgeInsets.symmetric(vertical: 8.0),



                    itemCount: mensagens.length,



                    itemBuilder: (context, index) {



                      final mensagem = mensagens[index];



                      final eMinhaMensagem = mensagem.senderId == _meuId;



  



                      return Align(



                        alignment: eMinhaMensagem



                            ? Alignment.centerRight



                            : Alignment.centerLeft,



                        child: Container(



                          padding: const EdgeInsets.symmetric(



                              vertical: 10, horizontal: 16),



                          margin: const EdgeInsets.symmetric(



                              vertical: 4, horizontal: 8),



                          decoration: BoxDecoration(



                            color: eMinhaMensagem



                                ? theme.colorScheme.primary



                                : theme.colorScheme.surfaceVariant,



                            borderRadius: BorderRadius.only(



                              topLeft: const Radius.circular(16),



                              topRight: const Radius.circular(16),



                              bottomLeft: eMinhaMensagem



                                  ? const Radius.circular(16)



                                  : const Radius.circular(0),



                              bottomRight: eMinhaMensagem



                                  ? const Radius.circular(0)



                                  : const Radius.circular(16),



                            ),



                          ),



                          child: Column(



                            crossAxisAlignment: eMinhaMensagem



                                ? CrossAxisAlignment.end



                                : CrossAxisAlignment.start,



                            children: [



                              Text(



                                mensagem.texto,



                                style: TextStyle(



                                  color: eMinhaMensagem



                                      ? theme.colorScheme.onPrimary



                                      : theme.colorScheme.onSurfaceVariant,



                                ),



                              ),



                              if (mensagem.timestamp != null)



                                Padding(



                                  padding: const EdgeInsets.only(top: 4.0),



                                  child: Text(



                                    DateFormat('HH:mm')



                                        .format(mensagem.timestamp!.toDate()),



                                    style: TextStyle(



                                      color: eMinhaMensagem



                                          ? theme.colorScheme.onPrimary.withOpacity(0.7)



                                          : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),



                                      fontSize: 10,



                                    ),



                                  ),



                                ),



                            ],



                          ),



                        ),



                      );



                    },



                  );



                },



              ),



            ),



            // Área de input de mensagem



            Container(



              padding: const EdgeInsets.all(8.0),



              decoration: BoxDecoration(



                color: theme.colorScheme.surface,



                boxShadow: [



                  BoxShadow(



                    color: Colors.black.withOpacity(0.05),



                    spreadRadius: 1,



                    blurRadius: 10,



                    offset: const Offset(0, -1),



                  ),



                ],



              ),



              child: SafeArea(



                child: Row(



                  children: [



                    Expanded(



                      child: TextField(



                        controller: _controller,



                        decoration: InputDecoration(



                          hintText: 'Digite uma mensagem...',



                          filled: true,



                          fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),



                          border: OutlineInputBorder(



                            borderRadius: BorderRadius.circular(30),



                            borderSide: BorderSide.none,



                          ),



                          contentPadding:



                              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),



                        ),



                        onSubmitted: (_) => _enviarMensagem(),



                        enabled: _meuId != null,



                      ),



                    ),



                    const SizedBox(width: 8),



                    IconButton.filled(



                      onPressed: _meuId != null ? _enviarMensagem : null,



                      icon: const Icon(Icons.send),



                      style: IconButton.styleFrom(



                        backgroundColor: theme.colorScheme.primary,



                        foregroundColor: theme.colorScheme.onPrimary,



                      ),



                    ),



                  ],



                ),



              ),



            ),



          ],



        ),



      );



    }

}