import 'package:flutter/material.dart';

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
