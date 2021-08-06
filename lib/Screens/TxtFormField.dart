import 'package:flutter/material.dart';

class TxtFormField extends StatefulWidget {
  final String hint;
  final String label;
  TextEditingController controller;
  final void Function() onSubmit;
  FocusNode? focus;

  TxtFormField({
    this.hint = '',
    required this.label,
    required this.controller,
    Key? key,
    required void Function() this.onSubmit,
    this.focus,
  }) : super(key: key);

  @override
  TxtFormFieldState createState() => TxtFormFieldState();
}

class TxtFormFieldState extends State<TxtFormField> {
  void onSubmit(String? _) {
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: TextFormField(
        focusNode: widget.focus,
        onFieldSubmitted: onSubmit,
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
