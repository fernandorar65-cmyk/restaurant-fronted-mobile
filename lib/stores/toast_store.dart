import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 'info' | 'success' | 'warning' | 'error'
typedef ToastTone = String;

class Toast {
  const Toast({required this.id, required this.title, this.message, this.tone = 'info'});

  final int id;
  final String title;
  final String? message;
  final ToastTone tone;
}

/// Avisos flotantes de la app. Se muestran con `ToastHost` (ver `app.dart`).
/// Uso: `context.read<ToastStore>().show('Guardado', tone: 'success')`.
class ToastStore extends ChangeNotifier {
  int _nextId = 1;
  List<Toast> toasts = const [];

  void dismiss(int id) {
    toasts = toasts.where((toast) => toast.id != id).toList();
    notifyListeners();
  }

  void show(String title, {String? message, ToastTone tone = 'info', bool sound = false, bool vibrate = false, int durationMs = 6000}) {
    final id = _nextId++;
    toasts = [...toasts, Toast(id: id, title: title, message: message, tone: tone)];
    notifyListeners();

    if (sound) {
      SystemSound.play(SystemSoundType.alert);
    }

    if (vibrate || sound) {
      HapticFeedback.mediumImpact();
    }

    Timer(Duration(milliseconds: durationMs), () => dismiss(id));
  }
}
