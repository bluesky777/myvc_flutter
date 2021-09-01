import 'package:flutter/material.dart';

class DrawAnimation extends StatefulWidget {
  const DrawAnimation({Key? key}) : super(key: key);

  @override
  _DrawAnimationState createState() => _DrawAnimationState();
}

class _DrawAnimationState extends State<DrawAnimation> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo,
    );
  }
}
