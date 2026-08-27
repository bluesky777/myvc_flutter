
import 'package:flutter/material.dart';

import '../../constantes.dart';
import '../../Utils/Anchos.dart';

class InputContainer extends StatelessWidget {
  const InputContainer({
    super.key,
    required this.child
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      width: Anchos.bandaDeLogin(context),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: kPrimaryColor.withAlpha(50),
      ),

      child: child,
    );
  }
}