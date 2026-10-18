import 'types.dart';

const Map<TableFloorStatus, String> floorStatusLabel = {
  'occupied': 'Ocupada',
  'available': 'Libre',
  'reserved': 'Reservada',
  'cleaning': 'Limpieza',
};

const Map<StaffArea, String> staffAreaLabel = {
  'kitchen': 'Cocina',
  'floor': 'Sala',
  'support': 'Soporte',
};

const Map<StaffShiftStatus, String> staffStatusLabel = {
  'on-shift': 'En turno',
  'break': 'Descanso',
  'absent': 'Ausente',
};

const Map<TableStatus, String> tableStatusLabel = {
  'active': 'Activa',
  'inactive': 'Inactiva',
  'maintenance': 'Mantenimiento',
};

const Map<RestaurantOperationalStatus, String> restaurantStatusLabel = {
  'active': 'Activa',
  'inactive': 'Inactiva',
  'suspended': 'Suspendida',
};

// ignore: constant_identifier_names
const List<String> CURRENCY_OPTIONS = ['EUR', 'PEN', 'USD', 'MXN', 'COP', 'CLP', 'ARS'];

// ignore: constant_identifier_names
const List<String> TIMEZONE_OPTIONS = [
  'Europe/Madrid',
  'America/Lima',
  'America/Bogota',
  'America/Mexico_City',
  'America/Santiago',
  'America/Argentina/Buenos_Aires',
  'America/New_York',
];
