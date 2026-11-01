import 'package:flutter/material.dart';

/// Logo de la app (mesa con sillas dentro del círculo verde y azul).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final inner = size * 0.84;

    // Placa blanca, como el ícono de la app: el azul del logo no se lee sobre el tema oscuro.
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Image.asset(
        'assets/branding/logo.png',
        width: inner,
        height: inner,
        // Decodifica al tamaño en pantalla, no a los 512 px del archivo.
        cacheWidth: (inner * MediaQuery.devicePixelRatioOf(context)).round(),
        semanticLabel: 'Logo',
      ),
    );
  }
}
