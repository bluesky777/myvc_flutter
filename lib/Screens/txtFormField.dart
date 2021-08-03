import 'package:flutter/material.dart';

class txtFormField extends StatelessWidget {
  final String hint;
  final String label;

  const txtFormField({this.hint = '', required this.label, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: TextFormField(
        decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: this.hint,
            labelText: this.label),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Ingrese texto';
          }
          return null;
        },
        onChanged: (value) {
          print(value);
        },
      ),
    );
  }
}
