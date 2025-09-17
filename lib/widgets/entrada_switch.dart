import 'package:flutter/material.dart';

class EntradaSwitch extends StatefulWidget {
  const EntradaSwitch({super.key});

  @override
  _EntradaSwitchState createState() => _EntradaSwitchState();
}

class _EntradaSwitchState extends State<EntradaSwitch> {
  bool _gmail = false;
  bool _whatsapp = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notificações"),
      ),
      body: Container(
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
            ),
            SwitchListTile(
                activeThumbColor: Colors.red,
                title: const Text("Gmail: "),
                value: _gmail,
                onChanged: (bool valor) {
                  setState(() {
                    _gmail = valor;
                  });
                }
            ),
            SwitchListTile(
                activeThumbColor: Colors.red,
                title: const Text("WhatsApp: "),
                value: _whatsapp,
                onChanged: (bool valor) {
                  setState(() {
                    _whatsapp = valor;
                  });
                }
            ),
            ElevatedButton(
                child: const Text("Salvar"),
                onPressed: () {
                  if (_gmail) {
                    print("Escolha: ativar Gmail");
                  } else {
                    print("Escolha: desativar Gmail");
                  }
                  if (_whatsapp) {
                    print("Escolha: ativar WhatsApp");
                  } else {
                    print("Escolha: desativar WhatsApp");
                  }
                }
            ),

            /*Text("Gmail: "),
            Switch(
                value: _selecionado,
                onChanged: (bool valor){
                  setState(() {
                    _selecionado = valor;
                  });
                }
            ),*/
          ],
        ),
      ),
    );
  }
}
