
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myvc_flutter/Screens/Login/RoundedPasswordInput.dart';
import 'package:myvc_flutter/constantes.dart';

import 'Login/RoundedButton.dart';
import 'Login/RoundedInput.dart';


class LoginAnimScreen extends StatefulWidget {
  const LoginAnimScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _LoginAnimScreenState createState() => _LoginAnimScreenState();
}

class _LoginAnimScreenState extends State<LoginAnimScreen> with SingleTickerProviderStateMixin {

  bool isLogin = true;
  Animation<double>? containerSize;
  AnimationController? animationController;
  Duration animationDuration = Duration(milliseconds: 270);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIOverlays([]);

    animationController = AnimationController(vsync: this, duration: animationDuration);
  }

  @override
  void dispose() {
    if(animationController != null) animationController!.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    Size size = MediaQuery.of(context).size;

    double viewInset = MediaQuery.of(context).viewInsets.bottom;
    double defaultLoginSize = size.height - (size.height * 0.2);
    double defaultRegisterSize = size.height - (size.height * 0.1);

    containerSize = Tween<double>(begin: size.height * 0.1, end: defaultRegisterSize).animate(CurvedAnimation(parent: animationController!, curve: Curves.linear));

    return Scaffold(
      body: Stack(
        children: [
          // Cancel button
          Align(
            alignment: Alignment.center,
            child: Container(
              width: size.width,
              height: size.height * 0.1,
              alignment: Alignment.topCenter,

              child: IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  animationController?.reverse();
                  setState(() {
                    isLogin = !isLogin;
                  });
                },
                color: kPrimaryColor,
              ),
            ),
          ),

          // Login form
          Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              child: Container(
                width: size.width,
                height: defaultLoginSize,

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    Text(
                      'Bienvenido',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold
                      ),
                    ),

                    Image(image: AssetImage('images/at_computer.png'), height: 200,),

                    SizedBox(height: 40,),

                    RoundedInput(icon: Icons.mail, hint: 'Usuario',),

                    RoundedPasswordInput(hint: 'Contraseña'),

                    RoundedButton(title: 'Entrar'),

                  ],
                ),
              ),
            ),
          ),

          // BOTÓN PARA MOSTRAR SERVIDORES
          AnimatedBuilder(
            animation: animationController!,
            builder: (context, child) => buildRegisterContainer(),
          ),
        ],
      ),
    );
  }

  Widget buildRegisterContainer() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        height: containerSize?.value,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(100),
            topRight: Radius.circular(100),
          ),
          color: KBackgroundColor,
        ),

        alignment: Alignment.center,
        child: GestureDetector(
            onTap: () {
              animationController?.forward();

              setState(() {
                isLogin = !isLogin;
              });
            },
            child: Text(
                'Selecciona tu colegio',
                style: TextStyle(
                  fontSize: 18,
                  color: kPrimaryColor,
                )
            )
        ),
      ),

    );
  }
}
