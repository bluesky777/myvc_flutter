import 'package:flutter/material.dart';

import '../../constantes.dart';
import 'InputContainer.dart';

class RoundedInput extends StatelessWidget {
  RoundedInput({
    Key? key,
    required this.icon,
    required this.hint,
    this.controller,
  }) : super(key: key);

  final IconData icon;
  final String hint;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return InputContainer(
      child: TextField(
        controller: controller,
        cursorColor: kPrimaryColor,
        decoration: InputDecoration(
          icon: Icon(
            icon,
            color: kPrimaryColor,
          ),
          hintText: hint,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
