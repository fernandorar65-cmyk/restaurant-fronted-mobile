import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'app.dart';
import 'core/storage/local_storage.dart';
import 'stores/cart_store.dart';
import 'stores/checkout_store.dart';
import 'stores/diner_store.dart';
import 'stores/session_store.dart';
import 'stores/site_activity_store.dart';
import 'stores/theme_store.dart';
import 'stores/toast_store.dart';
import 'widgets/feedback/splash_screen.dart';

void main() {
  // La pantalla nativa sigue visible hasta que la de carga tenga el logo listo (ver SplashScreen).
  WidgetsFlutterBinding.ensureInitialized().deferFirstFrame();
  runApp(const _Bootstrap());
}

/// Lo que la app necesita antes de crear los stores (leen el almacenamiento local al construirse).
Future<void> _initServices() async {
  await LocalStorage.init();
  await initializeDateFormatting('es');
  tz_data.initializeTimeZones();
}

/// Muestra la pantalla de carga mientras se inicializa la app y luego la desvanece sobre ella.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  Widget? _app;
  bool _splashVisible = true;

  @override
  void initState() {
    super.initState();
    _initServices().then((_) {
      if (mounted) setState(() => _app = _buildApp());
    });
  }

  Widget _buildApp() {
    final session = SessionStore();
    final toast = ToastStore();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeStore()),
        ChangeNotifierProvider.value(value: toast),
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => DinerStore()),
        ChangeNotifierProvider(create: (_) => CartStore()),
        ChangeNotifierProvider(create: (_) => CheckoutStore()),
        ChangeNotifierProvider(create: (_) => SiteActivityStore(session, toast)),
      ],
      child: const RestaurantApp(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // La app se arma debajo en cuanto está lista, para que al desvanecerse la carga ya esté pintada.
          ?_app,
          if (_splashVisible)
            SplashScreen(
              // Con clave, la pantalla de carga conserva su animación cuando la app aparece debajo.
              key: const ValueKey('splash'),
              ready: _app != null,
              onFinished: () => setState(() => _splashVisible = false),
            ),
        ],
      ),
    );
  }
}
