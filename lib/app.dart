import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'stores/diner_store.dart';
import 'stores/session_store.dart';
import 'stores/theme_store.dart';
import 'widgets/feedback/toast_host.dart';

class RestaurantApp extends StatefulWidget {
  const RestaurantApp({super.key});

  @override
  State<RestaurantApp> createState() => _RestaurantAppState();
}

class _RestaurantAppState extends State<RestaurantApp> {
  late final GoRouter _router = createRouter(
    session: context.read<SessionStore>(),
    diner: context.read<DinerStore>(),
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeStore>();

    return MaterialApp.router(
      title: 'Restaurant CMR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme.mode,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
      builder: (context, child) => ToastHost(
        // `_router.state` falla en el primer frame, antes de que el guard asíncrono resuelva la ruta.
        isPortal: () => _router.routerDelegate.currentConfiguration.uri.path.startsWith('/owner'),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
