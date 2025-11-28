// lib/screens/tela_chat.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vango/models/mensagem.dart';
import 'package:vango/models/usuario.dart';
import '../widgets/neon_app_bar.dart';
import 'tela_notificacoes.dart';

class TelaChat extends StatefulWidget {
  final String chatId;
  final String recipientId;

  const TelaChat({
    super.key,
    required this.chatId,
    required this.recipientId,
  });

  @override
  State<TelaChat> createState() => _TelaChatState();
}

class _TelaChatState extends State<TelaChat> {
  final _controller = TextEditingController();
  final String? _meuId = FirebaseAuth.instance.currentUser?.uid;
  late final Stream<List<Mensagem>> _messagesStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _chatSubscription;

  // State for inquiry chat logic
  bool _isLoadingDetails = true;
  String? _chatStatus;
  bool _isCurrentUserDriver = false;
  String _recipientName = "...";

  @override
  void initState() {
    super.initState();
    _loadChatDetails();
    _startChatStatusListener();

    _messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Mensagem.fromSnapshot(doc)).toList());
  }

  @override
  void dispose() {
    _controller.dispose();
    _chatSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadChatDetails() async {
    if (_meuId == null) return;

    try {
      // Fetch current user's role and recipient's name in parallel
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(_meuId).get(),
        FirebaseFirestore.instance.collection('users').doc(widget.recipientId).get(),
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get(),
      ]);

      final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final recipientDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      final chatDoc = results[2] as DocumentSnapshot<Map<String, dynamic>>;
      
      if (mounted) {
        setState(() {
          _isCurrentUserDriver = UserRole.fromString(userDoc.data()?['role']) == UserRole.motorista;
          _recipientName = recipientDoc.data()?['nome'] ?? 'Usuário';
          
          if(chatDoc.exists) {
             _chatStatus = chatDoc.data()?['status'];
          }
          _isLoadingDetails = false;
        });
      }

    } catch (e) {
      // Handle error
       if (mounted) {
         setState(() {
           _isLoadingDetails = false;
         });
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar detalhes do chat: $e')));
       }
    }
  }

  void _startChatStatusListener() {
    _chatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((doc) {
      if (!mounted) {
        return;
      }
      setState(() {
        _chatStatus = doc.data()?['status'];
      });
    }, onError: (error) {
      debugPrint('Erro ao ouvir status do chat: $error');
    });
  }

  Future<void> _aceitarConversa() async {
    try {
        await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
            'status': 'active',
            'updatedAt': FieldValue.serverTimestamp(),
        });
    } catch(e) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao aceitar conversa: $e')));
        }
    }
  }

  Future<void> _recusarConversa() async {
    try {
      // Exclui o documento do chat
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).delete();
      
      // Retorna para a tela anterior
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao recusar conversa: $e')));
      }
    }
  }


  Future<void> _enviarMensagem() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty || _meuId == null || _chatStatus != 'active') {
      return;
    }

    final meuId = _meuId!;
    _controller.clear();
    final firestore = FirebaseFirestore.instance;

    final chatDocRef = firestore.collection('chats').doc(widget.chatId);
    final messagesColRef = chatDocRef.collection('messages');

    try {
      // Atualiza apenas o lastMessage, pois o chat já existe
      await chatDocRef.set({
        'lastMessage': {
          'text': texto,
          'senderId': meuId,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Adiciona a nova mensagem
      await messagesColRef.add({
        'text': texto,
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
    final parentTheme = Theme.of(context);

    final Color primaryColor = _isCurrentUserDriver
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).colorScheme.primary;
    final Color onPrimaryColor = _isCurrentUserDriver ? Colors.white : Colors.black;
    final Color surfaceVariantColor = Theme.of(context).colorScheme.surfaceVariant;
    final Color onSurfaceVariantColor = Colors.black; // Keep black for contrast on light variants

    return Theme(
      data: parentTheme.copyWith(
        colorScheme: parentTheme.colorScheme.copyWith(
          primary: primaryColor,
          onPrimary: onPrimaryColor,
          surfaceVariant: surfaceVariantColor,
          onSurfaceVariant: onSurfaceVariantColor,
          tertiaryContainer: primaryColor.withOpacity(0.2),
          onTertiaryContainer: onPrimaryColor,
        ),
      ),
      child: Builder( // Use Builder to get a new BuildContext
        builder: (context) {
          final currentTheme = Theme.of(context); // Access the new theme here
          return Scaffold(
            appBar: NeonAppBar(
              title: _recipientName,
              onNotificationsPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TelaNotificacoes()),
                );
              },
            ),
            body: _isLoadingDetails
              ? const Center(child: CircularProgressIndicator())
              : _chatStatus == null
                  ? Center(
                      child: Text(
                        'Esta conversa não está mais disponível.',
                        style: TextStyle(color: currentTheme.colorScheme.onSurfaceVariant), // Use new theme
                      ),
                    )
                  : Column(
                      children: [
                        // Barra para aceitar a conversa
                        if (_isCurrentUserDriver && _chatStatus == 'inquiry')
                          _buildAcceptChatBar(), // This widget will also use Theme.of(context) internally

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
                                            ? currentTheme.colorScheme.primary // Use new theme
                                            : currentTheme.colorScheme.surfaceVariant, // Use new theme
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
                                                  ? currentTheme.colorScheme.onPrimary // Use new theme
                                                  : currentTheme.colorScheme.onSurfaceVariant, // Use new theme
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
                                                      ? currentTheme.colorScheme.onPrimary // Use new theme
                                                          .withOpacity(0.7)
                                                      : currentTheme.colorScheme.onSurfaceVariant // Use new theme
                                                          .withOpacity(0.7),
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
                        _buildChatInputArea(currentTheme), // Pass new theme
                      ],
                    ),
          );
        },
      ),
    );
  }

  Widget _buildChatInputArea(ThemeData theme) {
    if (_chatStatus != 'active') {
      final text = _isCurrentUserDriver
          ? 'Confirme o contato para liberar o envio de mensagens.'
          : 'Aguardando aprovação do motorista para iniciar a conversa.';
      return Container(
        padding: const EdgeInsets.all(16.0),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Input de texto normal para chats ativos
    return Container(
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
                enabled: true,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _enviarMensagem,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptChatBar() {
    return Container(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(child: Text("Aceitar esta conversa?")),
          Row(
            children: [
              TextButton(
                onPressed: _recusarConversa,
                child: const Text("Recusar"),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _aceitarConversa,
                child: const Text("Aceitar"),
              ),
            ],
          )
        ],
      ),
    );
  }
}
