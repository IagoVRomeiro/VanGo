import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vango/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:vango/models/chat.dart'; 
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
  bool _chatExiste = true;

  // State for inquiry chat logic
  bool _isLoadingDetails = true;
  ChatStatus? _chatStatus; // Use ChatStatus enum
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
      final List<DocumentSnapshot<Map<String, dynamic>>> results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(_meuId).get(),
        FirebaseFirestore.instance.collection('users').doc(widget.recipientId).get(),
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get(),
      ]);

      final userDoc = results[0];
      final recipientDoc = results[1];
      final chatDoc = results[2];
      
      if (mounted) {
        setState(() {
          _isCurrentUserDriver = UserRole.fromString(userDoc.data()?['role']) == UserRole.motorista;
          _recipientName = recipientDoc.data()?['nome'] ?? 'Usuário';
          
          if(chatDoc.exists) {
             _chatStatus = ChatStatus.fromString(chatDoc.data()?['status']);
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
        _chatExiste = doc.exists;
        _chatStatus = ChatStatus.fromString(doc.data()?['status']);
      });
    }, onError: (error) {
      debugPrint('Erro ao ouvir status do chat: $error');
    });
  }

  bool get _chatLiberadoParaEnvio {
    if (!_chatExiste) return false;
    if (_chatStatus == null) return true;
    return _chatStatus == ChatStatus.active || _chatStatus == ChatStatus.inquiry;
  }

  Future<void> _enviarMensagem() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty || _meuId == null || !_chatLiberadoParaEnvio) {
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

    final colorScheme = parentTheme.colorScheme;
    final Color primaryColor =
        _isCurrentUserDriver ? colorScheme.secondary : colorScheme.primary;
    final Color onPrimaryColor =
        _isCurrentUserDriver ? colorScheme.onSecondary : colorScheme.onPrimary;
    final Color surfaceVariantColor = colorScheme.surfaceVariant;
    final Color onSurfaceVariantColor = colorScheme.onSurfaceVariant;

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
              showMenuButton: false,
              showBackButton: true,
              onNotificationsPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TelaNotificacoes()),
                );
              },
            ),
            body: _isLoadingDetails
              ? const Center(child: CircularProgressIndicator())
              : !_chatExiste
                  ? Center(
                      child: Text(
                        'Esta conversa não está mais disponível.',
                        style: TextStyle(color: currentTheme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : Column(
                      children: [
                        if (_chatStatus == ChatStatus.inquiry)
                          _buildInquiryInfoBar(currentTheme),

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
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              DateFormat('HH:mm')
                                                  .format(mensagem.timestamp.toDate()),
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
    if (!_chatLiberadoParaEnvio) {
      final text = _chatExiste
          ? (_isCurrentUserDriver
              ? 'Confirme o contato para liberar o envio de mensagens.'
              : 'Aguardando aprovação do motorista para iniciar a conversa.')
          : 'Esta conversa não está mais disponível.';
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
                  hintText: AppLocalizations.of(context)!.chatHint,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
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

  Widget _buildInquiryInfoBar(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final text = _isCurrentUserDriver
        ? l10n.chatInquiryDriver
        : l10n.chatInquiryStudent;
    return Container(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            _isCurrentUserDriver ? Icons.info_outline : Icons.chat_bubble_outline,
            color: theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
