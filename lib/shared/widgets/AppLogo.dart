import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 50});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Wai',
            style: TextStyle(
              color: const Color.fromARGB(255, 0, 255, 21),
              fontSize: size * 0.75,
              fontWeight: FontWeight.bold,
            ),
          ),
          Transform.translate(
            offset: const Offset(-24, 0), // 🔥 ajusta el valor hasta que quede justo
            child: Image.asset(
              'assets/logo.png',
              height: size,
            ),
          ),
        ],
      ),
    );
  }
}
