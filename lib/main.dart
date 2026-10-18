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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();
  await initializeDateFormatting('es');
  tz_data.initializeTimeZones();

  final session = SessionStore();
  final toast = ToastStore();

  runApp(
    MultiProvider(
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
    ),
  );
}
