import 'package:flutter/material.dart';
import 'acao_flutuante_item.dart';

class BotaoAcaoAnimado extends StatefulWidget {
  final List<AcaoFlutuanteItem> itens;
  final Color corDoBotao;
  final void Function(String valor) onAcaoSelecionada;

  // 🔹 Novo: callback para avisar quando o menu abre/fecha
  final VoidCallback? onMenuToggle;

  const BotaoAcaoAnimado({
    super.key,
    required this.itens,
    required this.corDoBotao,
    required this.onAcaoSelecionada,
    this.onMenuToggle,
  });

  @override
  State<BotaoAcaoAnimado> createState() => _BotaoAcaoAnimadoState();
}

class _BotaoAcaoAnimadoState extends State<BotaoAcaoAnimado>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }

    // 🔹 Notifica o pai (TelaMotorista) sobre a abertura/fechamento do menu
    widget.onMenuToggle?.call();
  }

  void _handleItemTap(String valor) {
    _toggle(); // fecha o menu
    Future.microtask(() {
      if (mounted) widget.onAcaoSelecionada(valor);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        // 🔹 Botões secundários (itens)
        ...widget.itens.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final bottomOffset = (index + 1) * 65.0;

          return Positioned(
            bottom: 0,
            right: 4,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -bottomOffset * _controller.value),
                  child: Opacity(
                    opacity: _controller.value,
                    child: child,
                  ),
                );
              },
              child: FloatingActionButton.extended(
                heroTag: item.valor,
                onPressed: () => _handleItemTap(item.valor),
                icon: Icon(item.icone),
                label: Text(item.texto),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 4,
              ),
            ),
          );
        }).toList(),

        // 🔹 Botão principal
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: widget.corDoBotao,
          foregroundColor: Colors.white,
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _controller,
            size: 30,
          ),
        ),
      ],
    );
  }
}
