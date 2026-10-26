import 'package:flutter/material.dart';

class SealLogo extends StatelessWidget {
  const SealLogo({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/cabadbaran_seal.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'City of Cabadbaran official seal',
      );
}
