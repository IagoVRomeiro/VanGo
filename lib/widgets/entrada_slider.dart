import 'package:flutter/material.dart';
class EntradaSlider extends StatefulWidget {
  const EntradaSlider({super.key});

  @override
  _EntradaSliderState createState() => _EntradaSliderState();
}

class _EntradaSliderState extends State<EntradaSlider> {
  double valor = 50;
  String label = "seleção";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Satisfação dos clientes"),
      ),
      body: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: <Widget>[
            Slider(
                value: valor, //definir o valor inicial
                min:0,
                max:100,
                label: label, //label dinamico
                divisions: 10, //define as divisoes entre o minimo e o maximo
                activeColor: Colors.red,
                inactiveColor: Colors.black12,
                onChanged: (double novoValor){
                  setState(() {
                    valor = novoValor;
                    label = "seleção: $novoValor";
                  });
                  // print("Valor selecionado: "+valor.toString());
                }
            ),
            ElevatedButton(
                child: const Text("Salvar",
                  style: TextStyle(
                      fontSize: 20
                  ),
                ),
                onPressed: () {
                  print("Valor salvo: $valor");
                }
            ),


          ],
        ),
      ),
    );
  }
}
