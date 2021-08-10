import 'package:flutter/material.dart';
import 'package:myvc_flutter/Utils/UriColegio.dart';



class ColegiosDropdownWidget extends StatefulWidget {
  
  final List<DropdownMenuItem<UriColegio>> itemsUriColegios;
  final void Function(UriColegio) onSelected;


  // Constructor
  const ColegiosDropdownWidget(this.itemsUriColegios, this.onSelected, { Key? key }) : super(key: key);


  @override
  _ColegiosDropdownWidgetState createState() => _ColegiosDropdownWidgetState();
}


class _ColegiosDropdownWidgetState extends State<ColegiosDropdownWidget> {


  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(width: 1, color: Colors.grey),
            borderRadius: BorderRadius.circular(5),
          ),
          child: DropdownButtonFormField(
              //value: listaUrisColes.length > 0 ? listaUrisColes[listaUrisColes.length-1] : null,
              //value: UriColegio(nombre: 'Otro', uri: 'otro'),
              decoration: InputDecoration(
                hintText: 'Este hint',
                labelText: 'Elija institución',
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white)),
              ),
              onChanged: (dynamic value) {
                widget.onSelected(value);
              },
              items: widget.itemsUriColegios),
        ),
      );
  }
}