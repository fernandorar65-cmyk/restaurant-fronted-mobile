# Cobertura de endpoints en Flutter

Referencia analizada: `restaurant-frontend/docs/endpoints/endpoints.md`.

El inventario compara método HTTP y patrón de ruta en el código fuente. Una coincidencia indica que existe una llamada y requiere verificar parámetros, autenticación, cuerpos y respuestas. La revisión es estática.

- 40 de 214 endpoints tienen una llamada localizada por método y ruta.
- 174 de 214 endpoints quedan sin llamada localizada.

La app del comensal sigue consultando `/customers` y colecciones del mock. En el panel quedan rutas como `/menuProducts`, `/inventoryItems` y `/expenseCategories`. Los listados deben adoptar `items` y `meta`, y cada operación debe enviar el alcance por sede u organización que indica el contrato.


## Autenticación del comensal

| Endpoint | Llamada en Flutter |
| --- | --- |
| `POST /api/v1/customer/auth/register` | Sin llamada localizada |
| `POST /api/v1/customer/auth/login` | Sin llamada localizada |
| `POST /api/v1/customer/auth/refresh` | Sin llamada localizada |
| `POST /api/v1/customer/auth/logout` | Sin llamada localizada |
| `POST /api/v1/customer/auth/forgot-password` | Sin llamada localizada |
| `POST /api/v1/customer/auth/reset-password` | Sin llamada localizada |

## Perfil del comensal

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /api/v1/customer/me` | Sin llamada localizada |
| `PATCH /api/v1/customer/me` | Sin llamada localizada |
| `PATCH /api/v1/customer/me/password` | Sin llamada localizada |
| `GET /api/v1/customer/me/attentions` | Sin llamada localizada |

## Sedes y carta

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /api/v1/restaurants` | [fetchPublicRestaurants](../lib/modules/restaurants/api.dart#L103) |
| `GET /api/v1/restaurants/slug/{slug}` | [fetchRestaurantBySlug](../lib/modules/restaurants/api.dart#L116) |
| `GET /api/v1/restaurants/{id}` | [fetchPublicRestaurantById](../lib/modules/restaurants/api.dart#L119) |
| `GET /api/v1/restaurants/{id}/menu` | [fetchPublicMenu](../lib/modules/menus/api.dart#L166) |
| `GET /api/v1/restaurants/{id}/menu/search` | Sin llamada localizada |

## QR de la mesa

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /api/v1/tables/qr/{token}` | Sin llamada localizada |

## Carrito (pedidos para llevar o delivery)

| Endpoint | Llamada en Flutter |
| --- | --- |
| `POST /api/v1/restaurants/{restaurant}/cart/validate` | Sin llamada localizada |

## Pedidos en la mesa

| Endpoint | Llamada en Flutter |
| --- | --- |
| `POST /api/v1/attentions` | Sin llamada localizada |
| `POST /api/v1/attentions/{id}/orders` | Sin llamada localizada |
| `DELETE /api/v1/attentions/{id}/items/{itemId}` | Sin llamada localizada |
| `GET /api/v1/attentions/{id}` | Sin llamada localizada |
| `GET /api/v1/attentions/{id}/bill` | Sin llamada localizada |
| `POST /api/v1/attentions/{id}/request-bill` | Sin llamada localizada |

## Autenticación del dueño y del personal

| Endpoint | Llamada en Flutter |
| --- | --- |
| `POST /api/v1/owner/auth/register` | Sin llamada localizada |
| `POST /api/v1/owner/auth/login` | [modules/auth/api.dart:149](../lib/modules/auth/api.dart#L149) |
| `POST /api/v1/owner/auth/refresh` | [core/http/http_client.dart:142](../lib/core/http/http_client.dart#L142) |
| `POST /api/v1/owner/auth/logout` | [modules/auth/api.dart:128](../lib/modules/auth/api.dart#L128) |
| `POST /api/v1/owner/auth/forgot-password` | Sin llamada localizada |
| `POST /api/v1/owner/auth/reset-password` | Sin llamada localizada |

## Mi cuenta y mis accesos

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /api/v1/owner/me` | Sin llamada localizada |
| `PATCH /api/v1/owner/me` | Sin llamada localizada |
| `GET /api/v1/owner/me/profile` | [modules/auth/api.dart:60](../lib/modules/auth/api.dart#L60) |
| `PATCH /api/v1/owner/me/password` | Sin llamada localizada |

## Organizaciones

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /organizations` | [modules/restaurants/api.dart:62](../lib/modules/restaurants/api.dart#L62) |
| `POST /organizations` | Sin llamada localizada |
| `GET /organizations/{id}` | Sin llamada localizada |
| `PATCH /organizations/{id}` | [modules/restaurants/api.dart:304](../lib/modules/restaurants/api.dart#L304) |
| `DELETE /organizations/{id}` | Sin llamada localizada |

## Sedes

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /restaurants` | [modules/restaurants/api.dart:72](../lib/modules/restaurants/api.dart#L72) |
| `POST /restaurants` | [modules/restaurants/api.dart:219](../lib/modules/restaurants/api.dart#L219) |
| `GET /restaurants/{id}` | [modules/restaurants/api.dart:94](../lib/modules/restaurants/api.dart#L94) |
| `PATCH /restaurants/{id}` | [modules/restaurants/api.dart:279](../lib/modules/restaurants/api.dart#L279) |
| `DELETE /restaurants/{id}` | Sin llamada localizada |

## Pisos

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /restaurant-floors` | Sin llamada localizada |
| `POST /restaurant-floors` | Sin llamada localizada |
| `GET /restaurant-floors/{id}` | Sin llamada localizada |
| `PATCH /restaurant-floors/{id}` | Sin llamada localizada |
| `DELETE /restaurant-floors/{id}` | Sin llamada localizada |

## Mesas y QR

| Endpoint | Llamada en Flutter |
| --- | --- |
| `POST /dining-tables/{id}/qr-code` | Sin llamada localizada |
| `DELETE /dining-tables/{id}/qr-code` | Sin llamada localizada |
| `GET /dining-tables` | Sin llamada localizada |
| `POST /dining-tables` | Sin llamada localizada |
| `GET /dining-tables/{id}` | Sin llamada localizada |
| `PATCH /dining-tables/{id}` | Sin llamada localizada |
| `DELETE /dining-tables/{id}` | Sin llamada localizada |

## Plano del salón

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /floor-plan` | Sin llamada localizada |

## Empleados

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /employees` | [modules/administration/api.dart:16](../lib/modules/administration/api.dart#L16) |
| `POST /employees` | [modules/administration/api.dart:68](../lib/modules/administration/api.dart#L68) |
| `GET /employees/{id}` | [modules/auth/api.dart:209](../lib/modules/auth/api.dart#L209) |
| `PATCH /employees/{id}` | [modules/administration/api.dart:52](../lib/modules/administration/api.dart#L52), [modules/administration/api.dart:210](../lib/modules/administration/api.dart#L210), [modules/administration/api.dart:221](../lib/modules/administration/api.dart#L221) |
| `DELETE /employees/{id}` | [modules/administration/api.dart:110](../lib/modules/administration/api.dart#L110) |

## Áreas de trabajo

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /work-areas` | Sin llamada localizada |
| `POST /work-areas` | Sin llamada localizada |
| `GET /work-areas/{id}` | Sin llamada localizada |
| `PATCH /work-areas/{id}` | Sin llamada localizada |
| `DELETE /work-areas/{id}` | Sin llamada localizada |

## Puestos

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /job-positions` | Sin llamada localizada |
| `POST /job-positions` | Sin llamada localizada |
| `GET /job-positions/{id}` | Sin llamada localizada |
| `PATCH /job-positions/{id}` | Sin llamada localizada |
| `DELETE /job-positions/{id}` | Sin llamada localizada |

## Usuarios

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /users` | [modules/administration/api.dart:180](../lib/modules/administration/api.dart#L180), [modules/auth/api.dart:142](../lib/modules/auth/api.dart#L142) |
| `POST /users` | [modules/auth/api.dart:175](../lib/modules/auth/api.dart#L175) |
| `GET /users/{id}` | [modules/auth/api.dart:194](../lib/modules/auth/api.dart#L194) |
| `PATCH /users/{id}` | [modules/administration/api.dart:95](../lib/modules/administration/api.dart#L95), [modules/administration/api.dart:99](../lib/modules/administration/api.dart#L99), [modules/administration/api.dart:107](../lib/modules/administration/api.dart#L107), [modules/administration/api.dart:190](../lib/modules/administration/api.dart#L190), [modules/administration/api.dart:218](../lib/modules/administration/api.dart#L218), [modules/auth/api.dart:262](../lib/modules/auth/api.dart#L262), [modules/auth/api.dart:278](../lib/modules/auth/api.dart#L278), [modules/auth/api.dart:292](../lib/modules/auth/api.dart#L292) |
| `DELETE /users/{id}` | Sin llamada localizada |

## Usuarios de la organización (membresías)

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /memberships` | Sin llamada localizada |
| `POST /memberships` | Sin llamada localizada |
| `GET /memberships/{id}` | Sin llamada localizada |
| `PATCH /memberships/{id}` | Sin llamada localizada |
| `DELETE /memberships/{id}` | Sin llamada localizada |

## Roles

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /roles` | [modules/administration/api.dart:26](../lib/modules/administration/api.dart#L26) |
| `POST /roles` | [modules/administration/api.dart:156](../lib/modules/administration/api.dart#L156) |
| `GET /roles/{id}` | [modules/auth/api.dart:20](../lib/modules/auth/api.dart#L20) |
| `PATCH /roles/{id}` | [modules/administration/api.dart:166](../lib/modules/administration/api.dart#L166) |
| `DELETE /roles/{id}` | [modules/administration/api.dart:176](../lib/modules/administration/api.dart#L176) |
| `GET /roles/{id}/permissions` | Sin llamada localizada |
| `POST /roles/{id}/permissions` | Sin llamada localizada |
| `DELETE /roles/{id}/permissions/{permissionId}` | Sin llamada localizada |

## Permisos

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /permissions` | Sin llamada localizada |
| `POST /permissions` | Sin llamada localizada |
| `GET /permissions/{id}` | Sin llamada localizada |
| `PATCH /permissions/{id}` | Sin llamada localizada |
| `DELETE /permissions/{id}` | Sin llamada localizada |

## Categorías de productos

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /categories` | Sin llamada localizada |
| `POST /categories` | Sin llamada localizada |
| `GET /categories/{id}` | Sin llamada localizada |
| `PATCH /categories/{id}` | Sin llamada localizada |
| `DELETE /categories/{id}` | Sin llamada localizada |

## Productos

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /products` | Sin llamada localizada |
| `POST /products` | Sin llamada localizada |
| `GET /products/{id}` | Sin llamada localizada |
| `PATCH /products/{id}` | Sin llamada localizada |
| `DELETE /products/{id}` | Sin llamada localizada |
| `GET /products/{id}/categories` | Sin llamada localizada |
| `POST /products/{id}/categories` | Sin llamada localizada |
| `DELETE /products/{id}/categories/{categoryId}` | Sin llamada localizada |
| `GET /products/{productId}/ingredients` | Sin llamada localizada |
| `POST /products/{productId}/ingredients` | Sin llamada localizada |
| `PATCH /products/{productId}/ingredients/{ingredientId}` | Sin llamada localizada |
| `DELETE /products/{productId}/ingredients/{ingredientId}` | Sin llamada localizada |

## Menús

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /menus` | [modules/menus/api.dart:76](../lib/modules/menus/api.dart#L76) |
| `POST /menus` | [modules/menus/api.dart:96](../lib/modules/menus/api.dart#L96) |
| `GET /menus/{id}` | Sin llamada localizada |
| `PATCH /menus/{id}` | [modules/menus/api.dart:106](../lib/modules/menus/api.dart#L106) |
| `DELETE /menus/{id}` | Sin llamada localizada |
| `GET /menus/{id}/products` | Sin llamada localizada |
| `POST /menus/{id}/products` | Sin llamada localizada |
| `PUT /menus/{id}/products/order` | Sin llamada localizada |
| `PATCH /menus/{id}/products/{productId}` | Sin llamada localizada |
| `DELETE /menus/{id}/products/{productId}` | Sin llamada localizada |
| `GET /menus/{menuId}/sections` | Sin llamada localizada |
| `POST /menus/{menuId}/sections` | Sin llamada localizada |
| `PUT /menus/{menuId}/sections/order` | Sin llamada localizada |
| `PATCH /menus/{menuId}/sections/{sectionId}` | Sin llamada localizada |
| `DELETE /menus/{menuId}/sections/{sectionId}` | Sin llamada localizada |

## Estados y tipos de servicio

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /attention-statuses` | Sin llamada localizada |
| `POST /attention-statuses` | Sin llamada localizada |
| `PATCH /attention-statuses/{id}` | Sin llamada localizada |
| `GET /order-statuses` | Sin llamada localizada |
| `POST /order-statuses` | Sin llamada localizada |
| `PATCH /order-statuses/{id}` | Sin llamada localizada |
| `GET /service-types` | Sin llamada localizada |
| `POST /service-types` | Sin llamada localizada |
| `PATCH /service-types/{id}` | Sin llamada localizada |

## Atenciones (mesas y pedidos)

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /attentions` | [modules/orders/api.dart:125](../lib/modules/orders/api.dart#L125) |
| `POST /attentions` | [modules/orders/api.dart:170](../lib/modules/orders/api.dart#L170) |
| `GET /attentions/{id}` | [modules/orders/api.dart:142](../lib/modules/orders/api.dart#L142) |
| `POST /attentions/{id}/orders` | Sin llamada localizada |
| `GET /attentions/{id}/timeline` | Sin llamada localizada |
| `GET /attentions/{id}/bill` | Sin llamada localizada |
| `POST /attentions/{id}/request-bill` | Sin llamada localizada |
| `POST /attentions/{id}/close` | Sin llamada localizada |
| `POST /attentions/{id}/cancel` | Sin llamada localizada |
| `PATCH /attentions/{id}/fulfillment/status` | Sin llamada localizada |
| `POST /attentions/orders/{orderId}/confirm` | Sin llamada localizada |
| `POST /attentions/orders/{orderId}/cancel` | Sin llamada localizada |

## Platos (cocina)

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /order-items` | Sin llamada localizada |
| `GET /order-items/{id}` | Sin llamada localizada |
| `POST /order-items/status` | Sin llamada localizada |
| `PATCH /order-items/{id}/status` | Sin llamada localizada |
| `GET /order-items/{id}/history` | Sin llamada localizada |

## Pagos

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /payments` | [modules/payments/api.dart:45](../lib/modules/payments/api.dart#L45), [modules/payments/api.dart:66](../lib/modules/payments/api.dart#L66) |
| `POST /payments` | [modules/payments/api.dart:118](../lib/modules/payments/api.dart#L118) |
| `GET /payments/balance/{attentionId}` | Sin llamada localizada |
| `GET /payments/{id}` | Sin llamada localizada |
| `POST /payments/{id}/cancel` | Sin llamada localizada |
| `PATCH /payments/{id}/status` | Sin llamada localizada |

## Unidades y tipos de movimiento

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /units-of-measure` | Sin llamada localizada |
| `GET /inventory-movement-types` | Sin llamada localizada |

## Categorías de insumos

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /inventory-categories` | Sin llamada localizada |
| `POST /inventory-categories` | Sin llamada localizada |
| `GET /inventory-categories/{id}` | Sin llamada localizada |
| `PATCH /inventory-categories/{id}` | Sin llamada localizada |
| `DELETE /inventory-categories/{id}` | Sin llamada localizada |

## Insumos

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /supplies` | Sin llamada localizada |
| `POST /supplies` | Sin llamada localizada |
| `GET /supplies/{id}` | Sin llamada localizada |
| `PATCH /supplies/{id}` | Sin llamada localizada |
| `DELETE /supplies/{id}` | Sin llamada localizada |

## Stock por sede

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /restaurant-supplies` | Sin llamada localizada |
| `POST /restaurant-supplies` | Sin llamada localizada |
| `GET /restaurant-supplies/{id}` | Sin llamada localizada |
| `PATCH /restaurant-supplies/{id}` | Sin llamada localizada |
| `DELETE /restaurant-supplies/{id}` | Sin llamada localizada |
| `GET /restaurant-supplies/{id}/movements` | Sin llamada localizada |
| `POST /restaurant-supplies/{id}/movements` | Sin llamada localizada |
| `POST /restaurant-supplies/{id}/counts` | Sin llamada localizada |

## Movimientos de inventario

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /inventory-movements` | Sin llamada localizada |
| `GET /inventory-movements/{id}` | Sin llamada localizada |
| `POST /inventory-movements/{id}/reverse` | Sin llamada localizada |

## Recetas

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /product-recipes/{productId}` | Sin llamada localizada |
| `PUT /product-recipes/{productId}/supplies/{supplyId}` | Sin llamada localizada |
| `DELETE /product-recipes/{productId}/supplies/{supplyId}` | Sin llamada localizada |

## Categorías de gastos

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /expense-categories` | Sin llamada localizada |
| `POST /expense-categories` | Sin llamada localizada |
| `GET /expense-categories/{id}` | Sin llamada localizada |
| `PATCH /expense-categories/{id}` | Sin llamada localizada |
| `DELETE /expense-categories/{id}` | Sin llamada localizada |

## Gastos

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /expenses` | [modules/expenses/api.dart:111](../lib/modules/expenses/api.dart#L111), [modules/expenses/api.dart:131](../lib/modules/expenses/api.dart#L131) |
| `POST /expenses` | [modules/expenses/api.dart:58](../lib/modules/expenses/api.dart#L58) |
| `GET /expenses/{id}` | Sin llamada localizada |
| `PATCH /expenses/{id}` | [modules/expenses/api.dart:70](../lib/modules/expenses/api.dart#L70) |
| `DELETE /expenses/{id}` | [modules/expenses/api.dart:77](../lib/modules/expenses/api.dart#L77) |

## Cierres del día

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /daily-closures/preview` | Sin llamada localizada |
| `GET /daily-closures` | Sin llamada localizada |
| `POST /daily-closures` | Sin llamada localizada |
| `PUT /daily-closures` | Sin llamada localizada |
| `GET /daily-closures/{id}` | Sin llamada localizada |

## Reportes

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /reports/daily-financials` | Sin llamada localizada |
| `GET /reports/restaurants-overview` | Sin llamada localizada |
| `GET /reports/metrics` | Sin llamada localizada |

## Imágenes

| Endpoint | Llamada en Flutter |
| --- | --- |
| `POST /uploads/images` | Sin llamada localizada |

## Catálogos de pagos

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /platform/payment-statuses` | Sin llamada localizada |
| `PATCH /platform/payment-statuses/{code}` | Sin llamada localizada |
| `GET /platform/payment-provider-status-mappings` | Sin llamada localizada |
| `POST /platform/payment-provider-status-mappings` | Sin llamada localizada |
| `PATCH /platform/payment-provider-status-mappings/{id}` | Sin llamada localizada |
| `POST /platform/payment-providers/{providerCode}/events` | Sin llamada localizada |
| `GET /platform/payment-provider-events` | Sin llamada localizada |

## Catálogos de inventario

| Endpoint | Llamada en Flutter |
| --- | --- |
| `PATCH /platform/units-of-measure/{code}` | Sin llamada localizada |
| `PATCH /platform/inventory-movement-types/{code}` | Sin llamada localizada |

## Errores registrados

| Endpoint | Llamada en Flutter |
| --- | --- |
| `GET /platform/error-logs` | Sin llamada localizada |
| `GET /platform/error-logs/{id}` | Sin llamada localizada |
