import 'package:flutter/material.dart';
import 'package:myvc_flutter/Menu/opcionesMenuPrincipal.dart';

class DrawAnimation extends StatefulWidget {
  const DrawAnimation({Key? key}) : super(key: key);

  @override
  _DrawAnimationState createState() => _DrawAnimationState();
}

class _DrawAnimationState extends State<DrawAnimation> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverPersistentHeader(
            floating: true,
            delegate: _MyUserHeader(),
          ),
          SliverList(delegate: SliverChildListDelegate(
              itemsMenuPrincipal
          ),)
        ],
      ),
    );
  }
}

class _MyUserHeader extends SliverPersistentHeaderDelegate {
  final double minExtend;
  final double maxExtend;

  _MyUserHeader({
    this.minExtend = 80,
    this.maxExtend = 300,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: AssetImage('assets/images/MyVc.png'),
          height: 200,
          fit: BoxFit.cover,
        ),
        Positioned(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Joseth David',
                style: TextStyle(
                  fontSize: 25.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Guerrero',
                style: TextStyle(
                  fontSize: 25.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          left: 16.0,
          right: 16.0,
          bottom: 25.0,
        ),
      ],
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
