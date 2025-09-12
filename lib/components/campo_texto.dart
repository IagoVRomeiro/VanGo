import 'package:flutter/material.dart';
class CampoTexto extends StatefulWidget {
  const CampoTexto({super.key});

  @override
  _CampoTextoState createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  final TextEditingController _textEditingController = TextEditingController(); //instanciar o objeto para controlar o campo de texto
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Entrada de dados"),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(32),
            child: TextField(
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                  labelText: "Digite um valor: "
              ),
              style: const TextStyle(
                fontSize: 30,
                color: Colors.red,
              ),
              controller: _textEditingController, //controlador do nosso campo de texto
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: (){
              print("Texto digitado: ${_textEditingController.text}");
            },
            child: Text("Salvar"),
          ),
        ],
      ),
    );
  }
}
