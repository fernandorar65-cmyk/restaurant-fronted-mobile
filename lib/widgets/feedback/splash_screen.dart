import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Tamaño del logo en la pantalla de carga nativa (`flutter_native_splash` en pubspec.yaml):
/// la animación arranca igual para que el paso de una a otra no se note.
const double _logoSize = 120;

const AssetImage _logo = AssetImage('assets/branding/logo.png');

/// Pantalla de carga animada: continúa la pantalla nativa (fondo blanco y logo centrado)
/// mientras la app se inicializa. El logo late, aparece el nombre y, cuando [ready] pasa
/// a true, el logo crece y todo se desvanece sobre la app; al terminar llama a [onFinished].
///
/// Va por encima de `MaterialApp`, así que no usa el tema: toma los colores de [AppColors.light],
/// igual que la pantalla nativa, que siempre es clara. `main` retiene el primer frame y esta
/// pantalla lo libera cuando el logo ya está decodificado, para no mostrar un cuadro en blanco.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.ready, required this.onFinished});

  final bool ready;
  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  late final AnimationController _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  // Latido de entrada: el logo crece un poco y vuelve a su tamaño.
  late final Animation<double> _pop = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0).chain(CurveTween(curve: Curves.easeInOutBack)), weight: 65),
  ]).animate(CurvedAnimation(parent: _intro, curve: const Interval(0, 0.6)));
  late final Animation<double> _brand = CurvedAnimation(parent: _intro, curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic));
  late final Animation<double> _loader = CurvedAnimation(parent: _intro, curve: const Interval(0.6, 1, curve: Curves.easeOut));
  late final Animation<double> _leave = CurvedAnimation(parent: _exit, curve: Curves.easeInCubic);

  bool _reduceMotion = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    precacheImage(_logo, context).whenComplete(() {
      WidgetsBinding.instance.allowFirstFrame();
      if (mounted) _start();
    });
  }

  void _start() {
    if (_reduceMotion) {
      // Sin movimiento: se muestra todo de una vez y al salir solo se desvanece.
      _intro.value = 1;
      _exit.duration = const Duration(milliseconds: 200);
      _maybeLeave();
      return;
    }

    _intro.forward().whenComplete(() {
      if (!mounted) return;
      if (widget.ready) {
        _maybeLeave();
      } else {
        // Si la carga tarda, el logo sigue respirando hasta que termine.
        _pulse.repeat(reverse: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) _maybeLeave();
  }

  /// Sale solo cuando la app está lista y la entrada terminó (para no cortarla a la mitad).
  void _maybeLeave() {
    if (!widget.ready || !_intro.isCompleted || _exit.isAnimating || _exit.isCompleted) return;

    _pulse.stop();
    _exit.forward().whenComplete(() {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const c = AppColors.light;
    final text = TextStyle(fontFamily: AppFonts.family, decoration: TextDecoration.none, color: c.heading);

    return Semantics(
      label: 'Cargando',
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _pulse, _exit]),
        builder: (context, _) {
          final breathe = 1 + 0.04 * Curves.easeInOut.transform(_pulse.value);
          final scale = _pop.value * breathe * (1 + 0.35 * _leave.value);

          return Opacity(
            opacity: 1 - _leave.value,
            child: ColoredBox(
              color: Colors.white,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // El logo queda en el centro exacto, como en la pantalla nativa.
                  Transform.scale(
                    scale: scale,
                    child: const Image(image: _logo, width: _logoSize, height: _logoSize, semanticLabel: 'Logo'),
                  ),
                  Transform.translate(
                    offset: Offset(0, _logoSize / 2 + 44 + 16 * (1 - _brand.value)),
                    child: Opacity(
                      opacity: _brand.value * (1 - _leave.value),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('RentaSol', style: AppFonts.title(fontSize: 28).merge(text)),
                          const SizedBox(height: 2),
                          Text(
                            'Pide desde tu mesa',
                            style: text.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: c.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, _logoSize / 2 + 120),
                    child: Opacity(
                      opacity: _loader.value * (1 - _leave.value),
                      child: SizedBox(
                        width: 96,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(minHeight: 4, color: c.primary, backgroundColor: c.surfaceContainer),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
