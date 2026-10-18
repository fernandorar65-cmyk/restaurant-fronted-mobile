# restaurant-fronted-mobile

Versión móvil (Flutter) de `vue-projects/restaurant-frontend`: mismas rutas, mismos datos
(`json-server` sobre `db.json`) y mismas reglas de negocio, con UI adaptada a móvil.

## Requisitos

- Flutter 3.47+ (`brew install --cask flutter`)
- Android: Android Studio + SDK (`flutter doctor --android-licenses`)
- iOS: Xcode completo + CocoaPods (`brew install cocoapods`)

## Correr

```sh
# 1. Backend: desde el proyecto Vue (--host 0.0.0.0 para que lo vea un teléfono físico)
cd ../../vue-projects/restaurant-frontend
npx json-server --host 0.0.0.0 --port 3001 db.json

# 2. App
flutter pub get
flutter run                     # emulador Android usa 10.0.2.2:3001; simulador iOS/web usan localhost:3001
flutter run -d chrome           # para probar rápido en el navegador
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3001   # teléfono físico (IP de tu Mac)
```

Otras variables: `--dart-define=PUBLIC_WEB_URL=https://tu-dominio` (origen de los enlaces de los QR de mesa).

## Estructura

Ver [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) (equivalencias Vue → Flutter y convenciones) y
[docs/contracts/](docs/contracts/) (API de datos de cada módulo).

## Diferencias con la versión web

- Escáner de QR de mesa con la cámara (inicio del comensal).
- Diálogos como hojas inferiores; tablas como tarjetas; arrastrar y soltar reemplazado por botones.
- Sin selector de archivos: imagen de producto por URL y comprobante de transferencia simulado.
- Cola de cocina portada pero apagada, igual que en web (`core/config/features.dart`).
