import 'dart:async';

import 'package:flutter/widgets.dart';

/// Reemplazo de tiempo real mientras el backend sea json-server: ejecuta `task`
/// cada `interval` y se pausa cuando la app pasa a segundo plano.
/// Llamar a [dispose] en el `dispose` del State.
class Poller with WidgetsBindingObserver {
  Poller(this.task, this.interval) {
    WidgetsBinding.instance.addObserver(this);
  }

  final FutureOr<void> Function() task;
  final Duration interval;
  Timer? _timer;
  bool _foreground = true;

  void start() {
    stop();
    _timer = Timer.periodic(interval, (_) {
      if (_foreground) {
        _run();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _run() {
    try {
      final result = task();
      if (result is Future) {
        result.catchError((_) {});
      }
    } catch (_) {
      // Error puntual: se reintenta en el próximo ciclo.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;

    if (_foreground && !wasForeground && _timer != null) {
      _run();
    }
  }

  void dispose() {
    stop();
    WidgetsBinding.instance.removeObserver(this);
  }
}
