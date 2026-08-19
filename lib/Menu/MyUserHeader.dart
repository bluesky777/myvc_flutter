import 'package:flutter/material.dart';
import 'package:myvc_flutter/Http/AuthService.dart';

class MyUserHeader extends SliverPersistentHeaderDelegate {
  final double minExtend;
  final double maxExtend;

  MyUserHeader({
    this.minExtend = 120,
    this.maxExtend = 300,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.lightBlueAccent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: AssetImage('assets/images/logoMy.png'),
            height: 200,
            fit: BoxFit.cover,
          ),
          Positioned(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AuthService.user.nombres ?? 'Sin identificar',
                  style: TextStyle(
                    fontSize: 25.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // El usuario, a la vista: es lo que queda firmando cada
                // tardanza, y así se nota de un vistazo si la sesión abierta
                // es la del docente anterior.
                Text(
                  AuthService.user.username,
                  style: TextStyle(
                    fontSize: 16.0,
                  ),
                ),
              ],
            ),
            left: 16.0,
            right: 16.0,
            bottom: 25.0,
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => this.maxExtend;

  @override
  double get minExtent => this.minExtend;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
