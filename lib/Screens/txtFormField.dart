import 'package:flutter/material.dart';

class txtFormField extends StatefulWidget {
  final String hint;
  final String label;
  TextEditingController? controller;


  txtFormField({this.hint = '', required this.label, this.controller, Key? key})
      : super(key: key);


  @override
  _txtFormField createState() => _txtFormField();
}

class _txtFormField extends State<txtFormField> {

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: TextFormField(
        obscureText: widget.label == 'Contraseña' ? true : false,
        controller: widget.controller,
        decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: widget.hint,
            labelText: widget.label),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Ingrese texto';
          }
          return null;
        },
      ),
    );
  }

}