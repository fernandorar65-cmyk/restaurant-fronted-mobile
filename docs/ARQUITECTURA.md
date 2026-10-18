# Arquitectura — restaurant-fronted-mobile

Versión móvil (Flutter) de `vue-projects/restaurant-frontend`. Mismas rutas, mismos datos
(`json-server` sobre `db.json`) y mismas reglas de negocio; la UI se adapta a pantallas táctiles.

## Correr la app

```sh
# 1. Backend (desde el proyecto Vue). --host 0.0.0.0 permite que un teléfono físico lo vea.
cd ../../vue-projects/restaurant-frontend && npx json-server --host 0.0.0.0 --port 3001 db.json

# 2. App
flutter run                                   # emulador Android → 10.0.2.2:3001, simulador iOS → localhost:3001
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3001   # teléfono físico en la misma red
```

## Estructura de `lib/`

| Vue (`src/`)                        | Flutter (`lib/`)                                      |
| ----------------------------------- | ----------------------------------------------------- |
| `app/config/env.ts`                 | `core/config/env.dart` (`AppConfig.apiBaseUrl`)       |
| `app/features.ts`                   | `core/config/features.dart`                           |
| `services/http/*`                   | `core/http/http_client.dart` (`http()`, `HttpError`)  |
| `localStorage`                      | `core/storage/local_storage.dart` (SharedPreferences) |
| `utils/*`                           | `core/utils/*` (+ `json.dart`: lectura tolerante)     |
| `assets/main.css` (tokens)          | `core/theme/app_colors.dart`, `app_theme.dart`        |
| `composables/usePolling`            | `core/polling.dart` (`Poller`)                        |
| `composables/useSiteContext`        | `core/site_context.dart` (`SiteContext`)              |
| `composables/useNow`                | `Timer.periodic` en el State                          |
| `stores/*` (Pinia)                  | `stores/*` (`ChangeNotifier` + `provider`)            |
| `app/router/*`                      | `router/*` (`go_router`, guardas en `app_router.dart`) |
| `layouts/CustomerLayout`            | `layouts/customer_shell.dart` (barra inferior)        |
| `layouts/PortalLayout` + sidebar    | `layouts/portal_shell.dart` (AppBar + Drawer)         |
| `components/base/*`                 | `widgets/base/*`                                      |
| `components/feedback/*`             | `widgets/feedback/*`                                  |
| `stores/confirm`                    | `widgets/feedback/confirm.dart` (`confirmAction`)     |
| `modules/<m>/{types,api,…}.ts`      | `modules/<m>/{types,api,…}.dart`                      |
| `modules/<m>/views/XView.vue`       | `modules/<m>/views/x_view.dart` (clase `XView`)       |
| `modules/<m>/components/Y.vue`      | `modules/<m>/widgets/y.dart` (clase `Y`)              |

## Convenciones

- **Nombres**: cada función/tipo exportado en TS conserva su nombre en Dart. Las uniones de
  strings (`'open' | 'closed'`) son `typedef X = String`. Los ids siempre son `String`.
- **Estado global**: `context.watch<DinerStore>()` para reconstruir, `context.read<…>()` en callbacks.
  Stores: `SessionStore`, `DinerStore`, `CartStore`, `CheckoutStore`, `ThemeStore`, `ToastStore`,
  `SiteActivityStore`.
- **Navegación**: rutas en `router/routes.dart` (`Routes.menu(slug)`, `Routes.siteOrders(slug)`…).
  `context.go(...)` para cambiar de sección, `context.push(...)` para apilar un detalle. Los query
  params se leen con `GoRouterState.of(context).uri.queryParameters`.
- **Vistas de sede**: reciben `siteSlug`; usan `SiteContext` para traducirlo al id, cargar la sede
  y exponer `restaurant`, `restaurantId`, `currency`, `isLoading`, `loadError`.
- **Diálogos**: `showBaseDialog(context, title: …, builder: …, footerBuilder: …)` abre una hoja
  inferior (equivale a `BaseDialog.vue`). Confirmaciones con `confirmAction(context, …)`.
- **Avisos**: `context.read<ToastStore>().show('Título', message: '…', tone: 'success')`.
- **Tiempo real**: mientras el backend sea json-server, `Poller(task, Duration(seconds: 8))` y
  `SiteActivityStore.revision` (las vistas del portal recargan cuando cambia).
- **Colores**: siempre `context.colors.<token>` (mismos nombres que `main.css`, en camelCase);
  tipografías con `AppFonts.headline/label/body/eyebrow`.
- **Estados**: `StatusBadge(tone:, label:)` lleva ícono: el estado nunca depende solo del color.
- **Carga y error**: `SkeletonBlock` mientras carga, `EmptyState` sin datos, `DinerNotice` para avisos
  del comensal.
- **Móvil primero**: listas verticales en lugar de tablas, áreas táctiles ≥ 44 px, hojas inferiores
  en lugar de modales centrados, `RefreshIndicator` para recargar, `SafeArea` en pantallas sin shell.
