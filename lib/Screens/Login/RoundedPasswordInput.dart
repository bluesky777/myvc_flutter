import 'package:flutter/material.dart';

import '../../constantes.dart';
import 'InputContainer.dart';

class RoundedPasswordInput extends StatelessWidget {
  RoundedPasswordInput({
    Key? key,
    required this.hint,
    this.controller,
  }) : super(key: key);

  final String hint;
  TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return InputContainer(
      child: TextField(
        controller: controller,
        cursorColor: kPrimaryColor,
        obscureText: true,
        decoration: InputDecoration(
          icon: Icon(
            Icons.lock,
            color: kPrimaryColor,
          ),
          hintText: hint,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
