import 'package:flutter/material.dart';

class EntradaRadioButton extends StatefulWidget {
  const EntradaRadioButton({super.key});

  @override
  _EntradaRadioButtonState createState() => _EntradaRadioButtonState();
}

class _EntradaRadioButtonState extends State<EntradaRadioButton> {
  String _selecionado = "" ;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pesquisa de Satisfação"),
      ),
      body: Container(
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
            ),
            const Text("Satisfeito com o produto? "),
            RadioListTile(
              title: const Text("Sim"),
              value: "sim",
              groupValue: _selecionado,
              onChanged: (String? escolha){
                setState(() {
                  _selecionado = escolha!;
                });
              },
            ),
            RadioListTile(
              title: const Text("Não"),
              value: "nao",
              groupValue: _selecionado,
              onChanged: (String? escolha){
                setState(() {
                  _selecionado = escolha!;
                });
              },
            ),
            ElevatedButton(
                child: const Text("Salvar"),
                onPressed: (){
                  print("Item selecionado: $_selecionado");
                }
                ),
            /*
            Text("Masculino"),
            Radio(
                value: "m",
                groupValue: _selecionado,
                onChanged: (String escolha){
                  print("Resultado: " + escolha);
                  setState(() {
                    _selecionado = escolha;
                  });
                }
            ),
            Text("Feminino"),
            Radio(
                value: "f",
                groupValue: _selecionado,
                onChanged: (String escolha){
                  print("Resultado: " + escolha);
                  setState(() {
                    _selecionado = escolha;
                  });
                }
            ),*/
          ],
        ),
      ),
    );
  }
}
