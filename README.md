# restaurant-fronted-mobile

Versión móvil (Flutter) de `vue-projects/restaurant-frontend`, con interfaces para el comensal y el personal del restaurante. La integración con NestJS está en curso. Consulta la [cobertura de endpoints](docs/COBERTURA-ENDPOINTS.md).

## Requisitos

- Flutter 3.47+ (`brew install --cask flutter`)
- Android: Android Studio + SDK (`flutter doctor --android-licenses`)
- iOS: Xcode completo + CocoaPods (`brew install cocoapods`)

## Correr

```sh
flutter pub get

# API desplegada en Azure (por defecto)
flutter run

# API NestJS local. Levántala con npm run start:dev en el repositorio del backend.
flutter run --dart-define=API_ENV=local

# API local desde un teléfono físico (usa la IP de tu Mac)
flutter run --dart-define=API_ENV=local --dart-define=API_BASE_URL=http://192.168.1.20:3000
```

`API_ENV` vale `production` por defecto. En modo local, Android emulado usa `10.0.2.2:3000` y el simulador iOS, web y escritorio usan `localhost:3000`. `API_BASE_URL` tiene prioridad y debe contener el origen del servidor. El cliente agrega la ruta de cada endpoint.

Otras variables: `--dart-define=PUBLIC_WEB_URL=https://tu-dominio` (origen de los enlaces de los QR de mesa).

## Estructura

Ver [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) (equivalencias Vue → Flutter y convenciones) y
[docs/contracts/](docs/contracts/) (API de datos de cada módulo).

## Diferencias con la versión web

- Escáner de QR de mesa con la cámara (inicio del comensal).
- Diálogos como hojas inferiores; tablas como tarjetas; arrastrar y soltar reemplazado por botones.
- Sin selector de archivos: imagen de producto por URL y comprobante de transferencia simulado.
- Cola de cocina portada pero apagada, igual que en web (`core/config/features.dart`).
