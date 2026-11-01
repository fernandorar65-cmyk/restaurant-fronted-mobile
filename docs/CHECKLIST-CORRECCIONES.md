# Checklist de correcciones — restaurant-fronted-mobile

Surge del análisis de rendimiento y de arquitectura de la app Flutter (noviembre 2026).
Ordenado de mayor a menor prioridad. Los puntos de **Rendimiento** se pueden hacer ya,
sin cambios en el backend: json-server filtra en el servidor con `?_where=` (helper
`whereQuery` en [http_client.dart](../lib/core/http/http_client.dart)). No sirve `?campo=valor`,
porque json-server convierte `"1"` en número y no coincide con los ids de texto.

## Rendimiento

### Alta prioridad: red y batería

Hoy la app descarga colecciones completas y filtra en el teléfono, también durante el polling.
Ejemplo: "Mi pedido" baja **todos** los productos pedidos de todas las sedes cada 6 s
(53 KB por petición, unos 32 MB por hora de datos móviles).

- [x] **"Mi pedido": pedir solo los productos de la atención**
  (`/orderedProducts?attentionId=…`) en lugar de la colección completa.
  - Archivo: `fetchOrderedProductsByAttention` en [orders/api.dart](../lib/modules/orders/api.dart).
- [x] **"Cuenta": filtrar pagos por atención** (`/payments?attentionId=…`).
  - Archivo: `fetchPaymentsByAttention` en [payments/api.dart](../lib/modules/payments/api.dart).
- [x] **Portal: filtrar atenciones y productos por sede**
  (`/attentions?restaurantId=…`, `/orderedProducts?restaurantId=…`).
  - Archivo: `fetchAttentionsBySite` y `fetchOrderedProductsBySite` en [orders/api.dart](../lib/modules/orders/api.dart).
- [x] **Evitar la doble descarga en el portal:** que `SiteActivityStore` comparta lo que ya
  descargó, en vez de que cada vista vuelva a pedirlo cuando cambia `revision`.
  - Archivos: [site_activity_store.dart](../lib/stores/site_activity_store.dart),
    [site_orders_view.dart](../lib/modules/orders/views/site_orders_view.dart),
    `site_dashboard_view.dart`, `site_accounts_view.dart` y `kitchen_queue_view.dart`.
- [x] **Revisar los demás `http('/coleccion')` completos** y filtrarlos en el servidor.
  Hecho: carta (menús, categorías, productos), gastos, insumos, movimientos de inventario,
  cierres del día, historial de estados (cocina, timeline, solicitudes de cuenta) y
  productos de "Mis visitas".
- [ ] **Pendiente de backend: pagos por sede.** `payments` y `statusHistory` no guardan
  `restaurantId`, así que Cuentas, Métricas y Cierre del día siguen descargando todos los
  pagos (y Métricas, todo el historial). Filtrarlos por la lista de ids de atenciones haría
  crecer la URL sin límite. Hay que agregar `restaurantId` a esos registros o un endpoint por sede.

### Media prioridad: renderizado

- [ ] **Carta: construir solo los productos visibles.** Reemplazar el `Column` dentro de
  `SliverToBoxAdapter` por un `SliverList.builder` por categoría.
  - Archivo: [menu_view.dart](../lib/modules/menus/views/menu_view.dart).
- [ ] **Carta: que un "Agregar" no reconstruya la pantalla completa.** Quitar
  `context.watch<CartStore>()` de la raíz del `build`; que cada tarjeta escuche solo su
  cantidad con `context.select((CartStore c) => c.quantityOf(id))`.
  - Archivos: [menu_view.dart](../lib/modules/menus/views/menu_view.dart),
    [menu_product_card.dart](../lib/modules/menus/widgets/menu_product_card.dart).
- [ ] **Imágenes: decodificar al tamaño en pantalla.** Agregar `cacheWidth` a los 11
  `Image.network`. Hoy una foto de 500×375 ocupa unos 750 KB de memoria aunque se
  muestre a 64 px.
- [ ] **Imágenes: guardar en disco** (por ejemplo con `cached_network_image`), para no
  volver a descargarlas al reabrir la app.

### Baja prioridad

- [ ] **Zonas horarias:** cambiar `timezone/data/latest.dart` (1,1 MB) por
  `latest_10y.dart` (290 KB). Solo se usan 6 zonas.
  - Archivo: [main.dart](../lib/main.dart).
- [ ] **JSON grande fuera del hilo principal:** usar `compute()` en `http()` para respuestas
  de más de unos 100 KB (gastos: 279 KB, movimientos de inventario: 267 KB), o resolverlo
  filtrando en el servidor.
  - Archivo: [http_client.dart](../lib/core/http/http_client.dart).
- [ ] **`SiteActivityStore`:** llamar a `notifyListeners()` solo cuando cambie algo,
  no en cada ciclo de 8 s.
- [ ] **Listas que crecen:** pasar a `ListView.builder` las de pedidos, cuentas, gastos y
  movimientos de inventario (hoy hay 30 `ListView(children: …)` y solo 3 `.builder`).

### Verificación

- [ ] **Medir en un dispositivo físico** con `flutter run --profile` y DevTools → Performance:
  scroll de la carta y agregar productos sin fotogramas en rojo.
- [ ] **Comprobar con DevTools → Network** que el polling ya no descarga colecciones completas.

## Arquitectura

- [ ] **Crítico antes de producción: autenticación en el servidor.** Hoy `login()` descarga
  el usuario con su contraseña y la compara en la app, y el token es `json-<id>`.
  Se necesita login con JWT, sin exponer contraseñas, y permisos validados en el backend.
  - Archivos: [auth/api.dart](../lib/modules/auth/api.dart), [diners/api.dart](../lib/modules/diners/api.dart).
- [ ] **Acciones de varios pasos como un solo endpoint** del backend (enviar pedido, cerrar
  cuenta, cancelar atención). Hoy son varias escrituras desde la app y no son atómicas.
  - Archivos: [orders/api.dart](../lib/modules/orders/api.dart), [payments/api.dart](../lib/modules/payments/api.dart).
- [ ] **Cliente HTTP inyectable** (`ApiClient` vía Provider) en lugar de la función global
  `http()`, para poder testear con mocks.
- [ ] **Controllers por pantalla** en las vistas grandes del portal (tablero de pedidos,
  mesas, cuentas), siguiendo el patrón de `payments/checkout_controller.dart`.
- [ ] **Dependencias entre capas:** que `core/` no importe `modules/` (`http_client.dart`,
  `site_context.dart`) y cortar los ciclos entre módulos (`orders` ↔ `payments`,
  `orders` ↔ `restaurants`, `auth` ↔ `administration`).
- [ ] **Enums en lugar de `typedef X = String`** para los estados (38 casos), y dinero en
  céntimos (`int`) en lugar de `double`.
- [ ] **Tests de los flujos críticos:** pedido → cocina → cobro → cierre.
